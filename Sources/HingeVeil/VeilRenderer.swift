import AppKit
import CoreVideo
import MetalKit
import HingeVeilCore

struct GPUVeilParameters {
    var projection: SIMD4<Float>
    var appearance: SIMD4<Float>
    var counterProjection: SIMD4<Float>
}

final class VeilRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let composite: MTLRenderPipelineState
    private let gaussian: MTLComputePipelineState
    private let mailbox: ScreenMailbox?
    private var textureCache: CVMetalTextureCache?
    private var convertedSequence: UInt64?
    private var converted: CVMetalTexture?
    private var retainedBuffer: CVPixelBuffer?
    private var horizontal: MTLTexture?
    private var vertical: MTLTexture?
    private let demo: MTLTexture
    private let inflight = DispatchSemaphore(value: 2)
    private let stateLock = NSLock()
    private var targetAngle = 110.0
    private var options = VeilOptions()
    private var follower = AngleFollower()
    private var previousTime = ProcessInfo.processInfo.systemUptime
    private var waitingForPresentation = true
    private var renderGeneration: UInt64 = 0
    private var firstFrameAmount = 0.0
    private var renderedAmount = 0.0
    private var lastProjection: VeilProjection?
    private var lastSequence: UInt64?
    private var lastDrawableSize = CGSize.zero
    private var completedFrames = 0
    private var missingDrawables = 0
    private var presentedFrames = 0
    private var lastPresentedTime: Double?
    private var presentationIntervals = [Double]()
    var onFailure: ((AppText) -> Void)?
    var onFirstPresentation: (() -> Void)?

    func diagnostics() -> [String: Any] {
        stateLock.lock(); defer { stateLock.unlock() }
        let sorted = presentationIntervals.sorted()
        let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))]
        return ["completedFrames": completedFrames, "missingDrawables": missingDrawables,
                "presentedFrames": presentedFrames, "presentationP95ms": p95 * 1000,
                "presentationMaxms": (sorted.last ?? 0) * 1000,
                "waitingForPresentation": waitingForPresentation,
                "firstFrameAmount": firstFrameAmount, "renderedAmount": renderedAmount]
    }

    init(mailbox: ScreenMailbox? = nil, previewArtwork: Bool = false) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw RendererFailure.unavailable
        }
        self.device = device; commandQueue = queue; self.mailbox = mailbox
        let library: MTLLibrary
        if let compiled = Bundle.main.url(forResource: "Veil", withExtension: "metallib") {
            library = try device.makeLibrary(URL: compiled)
        } else {
            #if VEIL_PACKAGED
            throw RendererFailure.missingShader
            #else
            guard let source = Bundle.module.url(forResource: "Veil", withExtension: "metal") else {
                throw RendererFailure.missingShader
            }
            library = try device.makeLibrary(source: String(contentsOf: source), options: nil)
            #endif
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "veilTriangle")
        descriptor.fragmentFunction = library.makeFunction(name: "veilComposite")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        composite = try device.makeRenderPipelineState(descriptor: descriptor)
        guard let function = library.makeFunction(name: "veilGaussian") else { throw RendererFailure.missingShader }
        gaussian = try device.makeComputePipelineState(function: function)
        // Only the settings preview uses the tiger. Keep deterministic shapes
        // for GPU regression checks; the live overlay still reads its mailbox.
        demo = try previewArtwork ? Self.makePreviewArtwork(device: device)
            : Self.makeArtwork(device: device, width: 1280, height: 800)
        super.init()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }

    func configure(_ view: MTKView) {
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.delegate = self
    }

    func update(angle: Double, options: VeilOptions, reset: Bool = false) {
        stateLock.lock(); defer { stateLock.unlock() }
        targetAngle = angle
        self.options = options
        if reset {
            renderGeneration &+= 1
            follower.reset()
            _ = follower.advance(toward: options.startAngle, seconds: 0)
            previousTime = ProcessInfo.processInfo.systemUptime
            waitingForPresentation = true
            lastPresentedTime = nil; presentationIntervals.removeAll(keepingCapacity: true)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard inflight.wait(timeout: .now()) == .success else { return }
        let source: MTLTexture
        var sequence: UInt64 = 0
        var holdBuffer: CVPixelBuffer?
        var holdTexture: CVMetalTexture?
        if let mailbox {
            guard let frame = mailbox.snapshot().frame,
                  let cache = textureCache else { inflight.signal(); return }
            sequence = frame.sequence
            if convertedSequence != frame.sequence {
                var cvTexture: CVMetalTexture?
                let status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, frame.buffer,
                    nil, .bgra8Unorm, CVPixelBufferGetWidth(frame.buffer), CVPixelBufferGetHeight(frame.buffer), 0, &cvTexture)
                guard status == kCVReturnSuccess, let cvTexture else {
                    inflight.signal(); onFailure?("화면을 GPU에 연결하지 못했습니다."); return
                }
                converted = cvTexture; convertedSequence = frame.sequence; retainedBuffer = frame.buffer
            }
            guard let converted, let texture = CVMetalTextureGetTexture(converted) else { inflight.signal(); return }
            source = texture; holdTexture = converted; holdBuffer = retainedBuffer
        } else { source = demo }

        let now = ProcessInfo.processInfo.systemUptime
        stateLock.lock()
        let firstPresentation = waitingForPresentation
        // A newly shown overlay always starts with an identity frame. Starting
        // directly at a low sampled angle caused the whole effect to pop in.
        let angle = firstPresentation ? options.startAngle
            : follower.advance(toward: targetAngle, seconds: now - previousTime)
        let projection = VeilProjection(angle: angle, options: options)
        if firstPresentation { firstFrameAmount = projection.amount }
        renderedAmount = projection.amount
        previousTime = now
        let generation = renderGeneration
        stateLock.unlock()
        if !firstPresentation && projection == lastProjection && sequence == lastSequence && view.drawableSize == lastDrawableSize {
            inflight.signal(); return
        }
        guard let drawable = view.currentDrawable, let command = commandQueue.makeCommandBuffer() else {
            stateLock.lock(); missingDrawables += 1; stateLock.unlock()
            inflight.signal(); return
        }
        do {
            try encode(source: source, output: drawable.texture, projection: projection, command: command)
            drawable.addPresentedHandler { [weak self] presented in
                guard let self, presented.presentedTime > 0 else { return }
                self.stateLock.lock(); defer { self.stateLock.unlock() }
                self.presentedFrames += 1
                if let last = self.lastPresentedTime, presented.presentedTime > last {
                    self.presentationIntervals.append(presented.presentedTime - last)
                    if self.presentationIntervals.count > 240 { self.presentationIntervals.removeFirst() }
                }
                self.lastPresentedTime = presented.presentedTime
            }
            command.present(drawable)
            lastProjection = projection; lastSequence = sequence; lastDrawableSize = view.drawableSize
            stateLock.lock(); waitingForPresentation = false; stateLock.unlock()
            command.addCompletedHandler { [weak self, inflight, holdBuffer, holdTexture] result in
                _ = holdBuffer; _ = holdTexture // Retain zero-copy surfaces until the GPU finishes.
                if result.status == .completed, let self {
                    self.stateLock.lock(); self.completedFrames += 1; self.stateLock.unlock()
                }
                if result.status == .error {
                    DispatchQueue.main.async { self?.onFailure?("GPU 화면 처리가 중단되었습니다.") }
                } else if firstPresentation {
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.stateLock.lock()
                        let current = self.renderGeneration == generation
                        self.stateLock.unlock()
                        if current { self.onFirstPresentation?() }
                    }
                }
                inflight.signal()
            }
            command.commit()
        } catch { inflight.signal(); onFailure?(AppText(error.localizedDescription)) }
    }

    private func encode(source: MTLTexture, output: MTLTexture, projection: VeilProjection,
                        command: MTLCommandBuffer, applyBlur: Bool = true) throws {
        // Only the soft layer is half-resolution. The sharp desktop remains at
        // capture resolution; both blur passes cover the full normalized image.
        let blurWidth = max(2, source.width / 2)
        let blurHeight = max(2, source.height / 2)
        if horizontal?.width != blurWidth || horizontal?.height != blurHeight {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                width: blurWidth, height: blurHeight, mipmapped: false)
            descriptor.storageMode = .private
            descriptor.usage = [.shaderRead, .shaderWrite]
            horizontal = device.makeTexture(descriptor: descriptor)
            vertical = device.makeTexture(descriptor: descriptor)
        }
        var blurred = source
        if applyBlur && projection.amount > 0.0001 {
            guard let horizontal, let vertical else { throw RendererFailure.allocation }
            let radius = Float(projection.blurPixels * Double(source.width) / 1920 / 4)
            for (input, output, direction) in [
                (source, horizontal, SIMD2<Float>(radius, 0)),
                (horizontal, vertical, SIMD2<Float>(0, radius * Float(blurHeight) / Float(source.height)))
            ] {
                guard let encoder = command.makeComputeCommandEncoder() else { throw RendererFailure.allocation }
                var axis = direction
                encoder.setComputePipelineState(gaussian)
                encoder.setTexture(input, index: 0); encoder.setTexture(output, index: 1)
                encoder.setBytes(&axis, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
                let w = gaussian.threadExecutionWidth
                let h = min(8, gaussian.maxTotalThreadsPerThreadgroup / w)
                encoder.dispatchThreads(MTLSize(width: output.width, height: output.height, depth: 1),
                                        threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1))
                encoder.endEncoding()
            }
            blurred = vertical
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { throw RendererFailure.allocation }
        var values = GPUVeilParameters(
            projection: SIMD4(Float(projection.amount), Float(projection.topInset), Float(projection.sideInset), Float(projection.blurPixels)),
            appearance: SIMD4(Float(projection.feather), Float(projection.shade), Float(source.width), Float(source.height)),
            counterProjection: SIMD4(Float(projection.counterCompression), Float(projection.counterDepth), 0, 0))
        encoder.setRenderPipelineState(composite)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentTexture(blurred, index: 1)
        encoder.setFragmentBytes(&values, length: MemoryLayout<GPUVeilParameters>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    /// Uses only generated artwork, not the user's screen. Runs real GPU passes
    /// and checks their completion, output differences, and execution times.
    func selfCheck(directory: URL?) throws -> String {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: demo.width, height: demo.height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget, .shaderRead]
        guard let output = device.makeTexture(descriptor: descriptor) else { throw RendererFailure.allocation }
        var hashes = Set<UInt64>()
        var durations = [Double]()
        var openPixels = [UInt8]()
        var thirtyPercentDifference = (left: 0.0, middle: 0.0, right: 0.0)
        for index in 0..<39 {
            let level = index == 0 ? 2 : (index - 1) % 4 + 1
            let angle = index == 0 ? 110.0 : (index < 5 ? 32.0 : 67.5)
            guard let command = commandQueue.makeCommandBuffer() else { throw RendererFailure.allocation }
            let projection = VeilProjection(angle: angle, options: VeilOptions(blurLevel: level))
            try encode(source: demo, output: output, projection: projection, command: command)
            command.commit(); command.waitUntilCompleted()
            guard command.status == .completed else { throw command.error ?? RendererFailure.unavailable }
            if index >= 9 { durations.append((command.gpuEndTime - command.gpuStartTime) * 1000) }
            if index < 9 {
                var bytes = [UInt8](repeating: 0, count: demo.width * demo.height * 4)
                output.getBytes(&bytes, bytesPerRow: demo.width * 4,
                                from: MTLRegionMake2D(0, 0, demo.width, demo.height), mipmapLevel: 0)
                // Check broad landmark interiors; exact counter-projection,
                // enlargement bounds and edge clipping are checked separately.
                let green = (demo.height * 3 / 4 * demo.width + demo.width * 275 / 1000) * 4
                let yellow = (demo.height * 7 / 10 * demo.width + demo.width * 7 / 10) * 4
                guard Double(bytes[green + 1]) > Double(bytes[green + 2]) * 2,
                      Double(bytes[green + 1]) > Double(bytes[green]) * 1.05,
                      Double(bytes[yellow + 2]) > Double(bytes[yellow + 1]) * 1.1,
                      Double(bytes[yellow + 1]) > Double(bytes[yellow]) * 1.2 else {
                    throw RendererFailure.identicalFrames
                }
                let hash = bytes.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
                hashes.insert(hash)
                if index == 0 { openPixels = bytes }
                if index == 6 { // Default level 2 at the real test's 30% amount.
                    func difference(_ lowerX: Double, _ upperX: Double) -> Double {
                        var total = 0.0
                        var samples = 0
                        for y in (demo.height / 10)..<(demo.height * 6 / 10) {
                            for x in Int(Double(demo.width) * lowerX)..<Int(Double(demo.width) * upperX) {
                                let offset = (y * demo.width + x) * 4
                                for channel in 0..<3 {
                                    total += abs(Double(bytes[offset + channel]) - Double(openPixels[offset + channel]))
                                    samples += 1
                                }
                            }
                        }
                        return total / Double(max(1, samples))
                    }
                    thirtyPercentDifference = (difference(0, 0.06), difference(0.40, 0.60), difference(0.94, 1))
                    guard thirtyPercentDifference.left > 3, thirtyPercentDifference.right > 3 else {
                        throw RendererFailure.weakEdges
                    }
                }
                if let directory {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try Self.savePNG(bytes, width: demo.width, height: demo.height,
                                     to: directory.appendingPathComponent(index == 0 ? "open.png" :
                                        (index < 5 ? "blur-\(level).png" : "test30-blur-\(level).png")))
                }
            }
        }
        guard hashes.count == 9 else { throw RendererFailure.identicalFrames }
        let coordinateError = try checkGeometry(output: output)
        try checkSourceClipping(output: output)
        let contrast = try checkFullScreenBlur(output: output)
        durations.sort()
        return "GPU 검증 통과: 열린 화면 + 32도/30% 접힘의 블러 4단계(9개 출력) 구별. 30/25/20도 포함 제한 각도 보정 좌표 최대 오차 \(String(format: "%.2f", coordinateError))/255, 원본 밖 픽셀 가림 통과. 30% 기본 강도 RGB 평균 변화(0~255) 왼쪽 \(String(format: "%.2f", thirtyPercentDifference.left)) / 중앙 \(String(format: "%.2f", thirtyPercentDifference.middle)) / 오른쪽 \(String(format: "%.2f", thirtyPercentDifference.right)). 동일 보정·밝기 기준 격자 대비 감소 중앙 \(String(format: "%.1f", contrast.middle * 100))% / 양쪽 \(String(format: "%.1f", contrast.edge * 100))%. 4단계·4각도 하단 대비 감소 최대 \(String(format: "%.1f", contrast.maximumBottom * 100))%. 1280×800, GPU 중앙값 \(String(format: "%.2f", durations[durations.count / 2]))ms, 최대 \(String(format: "%.2f", durations.max() ?? 0))ms."
    }

    /// Validate the packaged illustration without reading the user's screen.
    /// The analytical shape/grid regression suite remains separate.
    func previewCheck(directory: URL?) throws -> String {
        let width = demo.width, height = demo.height
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.renderTarget, .shaderRead]
        guard let output = device.makeTexture(descriptor: descriptor) else { throw RendererFailure.allocation }
        var hashes = Set<UInt64>()
        for index in 0..<9 {
            let level = index == 0 ? 2 : (index - 1) % 4 + 1
            let angle = index == 0 ? 110.0 : (index < 5 ? 32.0 : 67.5)
            guard let command = commandQueue.makeCommandBuffer() else { throw RendererFailure.allocation }
            try encode(source: demo, output: output,
                projection: VeilProjection(angle: angle, options: VeilOptions(blurLevel: level)), command: command)
            command.commit(); command.waitUntilCompleted()
            guard command.status == .completed else { throw command.error ?? RendererFailure.unavailable }
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            output.getBytes(&bytes, bytesPerRow: width * 4,
                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            if index == 0 {
                for (x, y) in [(5, 5), (width - 6, 5), (5, height - 6), (width - 6, height - 6)] {
                    let offset = (y * width + x) * 4
                    guard bytes[offset..<offset + 3].allSatisfy({ $0 > 240 }),
                          bytes[offset + 3] == 255 else { throw RendererFailure.missingArtwork }
                }
                var inkPixels = 0
                for offset in stride(from: 0, to: bytes.count, by: 4) {
                    if bytes[offset] < 120 && bytes[offset + 1] < 120 && bytes[offset + 2] < 120 {
                        inkPixels += 1
                    }
                }
                guard inkPixels > width * height / 100 else { throw RendererFailure.missingArtwork }
            }
            hashes.insert(bytes.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 })
            if let directory {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let name = index == 0 ? "tiger-open.png" :
                    (index < 5 ? "tiger-32-blur-\(level).png" : "tiger-test30-blur-\(level).png")
                try Self.savePNG(bytes, width: width, height: height, to: directory.appendingPathComponent(name))
            }
        }
        guard hashes.count == 9 else { throw RendererFailure.identicalFrames }
        return "백호 미리보기 GPU 검증 통과: \(width)×\(height), 흰 도화지와 검은 그림선 확인, 열린 화면·32도·30% 접힘의 블러 4단계(9개 출력) 구별. 화면 캡처 없음."
    }

    /// Encode UV in the source's red/green channels and verify actual Metal
    /// readback against bounded CPU coordinates, not a reprojected camera view.
    /// Independent CPU derivative tests enforce the 12% panel enlargement cap.
    private func checkGeometry(output: MTLTexture) throws -> Double {
        let width = output.width, height = output.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                pixels[offset + 1] = UInt8(((Double(y) + 0.5) / Double(height) * 255).rounded())
                pixels[offset + 2] = UInt8(((Double(x) + 0.5) / Double(width) * 255).rounded())
                pixels[offset + 3] = 255
            }
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw RendererFailure.allocation }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: pixels, bytesPerRow: width * 4)
        var maximumError = 0.0
        for start in [85.0, 90, 95, 100] {
            for angle in [110.0, 89, 67.5, 50, 32, 30, 25, 20, 15] {
                for level in 1...4 {
                    let p = VeilProjection(angle: angle, options: VeilOptions(startAngle: start, blurLevel: level))
                    guard let command = commandQueue.makeCommandBuffer() else { throw RendererFailure.allocation }
                    try encode(source: texture, output: output, projection: p, command: command)
                    command.commit(); command.waitUntilCompleted()
                    guard command.status == .completed else { throw command.error ?? RendererFailure.unavailable }
                    output.getBytes(&pixels, bytesPerRow: width * 4,
                        from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
                    for x in [width / 4, width / 2, width * 3 / 4] {
                        for y in [height / 8, height / 3, height / 2, height * 4 / 5] {
                            let panelX = (Double(x) + 0.5) / Double(width)
                            let panelY = (Double(y) + 0.5) / Double(height)
                            let source = p.sourcePoint(x: panelX, y: panelY)
                            let offset = (y * width + x) * 4
                            let expected = [source.y, source.x].map { $0 * 255 * (1 - p.shadeAt(y: panelY)) }
                            for channel in 0..<2 {
                                let error = abs(Double(pixels[offset + 1 + channel]) - expected[channel])
                                maximumError = max(maximumError, error)
                                guard error < 2 else { throw RendererFailure.geometryMismatch }
                            }
                        }
                    }
                }
            }
        }
        return maximumError
    }

    /// Outside UVs must be hidden, not extended by the texture sampler. Use
    /// white pixels just INSIDE the aperture to isolate the source-edge mask.
    private func checkSourceClipping(output: MTLTexture) throws {
        let width = output.width, height = output.height
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor),
              let command = commandQueue.makeCommandBuffer() else { throw RendererFailure.allocation }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: pixels, bytesPerRow: width * 4)
        let p = VeilProjection(angle: 83, options: VeilOptions())
        try encode(source: texture, output: output, projection: p, command: command, applyBlur: false)
        command.commit(); command.waitUntilCompleted()
        guard command.status == .completed else { throw command.error ?? RendererFailure.unavailable }
        output.getBytes(&pixels, bytesPerRow: width * 4,
                        from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let y = height / 8
        for x in [1, width - 2] {
            let panelX = (Double(x) + 0.5) / Double(width)
            let panelY = (Double(y) + 0.5) / Double(height)
            let source = p.sourcePoint(x: panelX, y: panelY)
            let inset = p.sideInset * (1 - panelY) / (1 - p.topInset)
            guard min(panelX - inset, 1 - inset - panelX) > 0,
                  source.x < 0 || source.x > 1,
                  pixels[(y * width + x) * 4 + 2] == 0 else { throw RendererFailure.geometryMismatch }
        }
        guard pixels[(height / 2 * width + width / 2) * 4 + 2] > 200 else {
            throw RendererFailure.geometryMismatch
        }
    }

    /// Measure fine detail in the middle AND sides. Compare a sharp pass with
    /// the SAME warp/coverage/shade so resampling alone cannot count as blur.
    private func checkFullScreenBlur(output: MTLTexture) throws -> (middle: Double, edge: Double, maximumBottom: Double) {
        let width = output.width, height = output.height
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let value: UInt8 = (x / 4 + y / 4) % 2 == 0 ? 0 : 255
                for channel in 0..<3 { pixels[offset + channel] = value }
            }
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw RendererFailure.allocation }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: pixels, bytesPerRow: width * 4)
        var established = (middle: 0.0, edge: 0.0)
        var maximumBottom = 0.0
        for angle in [67.5, 32, 25, 20] {
            for level in 1...4 {
                let p = VeilProjection(angle: angle, options: VeilOptions(blurLevel: level))
                guard let referenceCommand = commandQueue.makeCommandBuffer() else { throw RendererFailure.allocation }
                try encode(source: texture, output: output, projection: p, command: referenceCommand, applyBlur: false)
                referenceCommand.commit(); referenceCommand.waitUntilCompleted()
                guard referenceCommand.status == .completed else { throw referenceCommand.error ?? RendererFailure.unavailable }
                var reference = pixels
                output.getBytes(&reference, bytesPerRow: width * 4,
                                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
                guard let command = commandQueue.makeCommandBuffer() else { throw RendererFailure.allocation }
                try encode(source: texture, output: output, projection: p, command: command)
                command.commit(); command.waitUntilCompleted()
                guard command.status == .completed else { throw command.error ?? RendererFailure.unavailable }
                output.getBytes(&pixels, bytesPerRow: width * 4,
                                from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
                func contrastLoss(_ lowerX: Double, _ upperX: Double, _ lowerY: Double = 0.4, _ upperY: Double = 0.6) -> Double {
                    var sum = 0.0, referenceSum = 0.0
                    for y in Int(Double(height) * lowerY)..<Int(Double(height) * upperY) {
                        let gain = 1 - p.shadeAt(y: (Double(y) + 0.5) / Double(height))
                        for x in Int(Double(width) * lowerX)..<Int(Double(width) * upperX) {
                            sum += abs(Double(pixels[(y * width + x) * 4 + 2]) / gain - 127.5)
                            referenceSum += abs(Double(reference[(y * width + x) * 4 + 2]) / gain - 127.5)
                        }
                    }
                    return 1 - sum / max(1, referenceSum)
                }
                let middle = contrastLoss(0.4, 0.6)
                let left = contrastLoss(0.08, 0.14), right = contrastLoss(0.86, 0.92)
                // Actual GPU detail at the hinge must remain markedly clearer
                // at all four radii, including 20/25-degree deep-angle output.
                let bottom = max(contrastLoss(0.4, 0.6, 0.94, 0.99),
                                 max(contrastLoss(0.08, 0.14, 0.94, 0.99), contrastLoss(0.86, 0.92, 0.94, 0.99)))
                guard bottom < 0.16, middle > bottom + 0.03,
                      min(left, right) > bottom + 0.03 else { throw RendererFailure.weakEdges }
                maximumBottom = max(maximumBottom, bottom)
                if angle == 67.5 && level == 2 {
                    // Preserve the established center/side haze above the fade.
                    guard middle > 0.30, left > 0.50, right > 0.50,
                          min(left, right) > middle + 0.15 else { throw RendererFailure.weakEdges }
                    established = (middle, (left + right) / 2)
                }
            }
        }
        return (established.middle, established.edge, maximumBottom)
    }

    private static func makePreviewArtwork(device: MTLDevice) throws -> MTLTexture {
        let mainURL = Bundle.main.url(forResource: "PreviewTiger", withExtension: "png")
        #if VEIL_PACKAGED
        let artworkURL = mainURL
        #else
        let artworkURL = mainURL ?? Bundle.module.url(forResource: "PreviewTiger", withExtension: "png")
        #endif
        guard let url = artworkURL else {
            throw RendererFailure.missingArtwork
        }
        return try MTKTextureLoader(device: device).newTexture(URL: url, options: [
            .SRGB: false,
            .origin: MTKTextureLoader.Origin.topLeft
        ])
    }

    private static func makeArtwork(device: MTLDevice, width: Int, height: Int) throws -> MTLTexture {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                var color: (UInt8, UInt8, UInt8) = (20, UInt8(35 + 40 * y / height), UInt8(50 + 40 * x / width))
                if x % 40 < 2 || y % 40 < 2 { color = (67, 88, 102) }
                if x > width / 9 && x < width * 4 / 9 && y > height / 6 && y < height * 5 / 6 { color = (55, 197, 167) }
                if x > width * 5 / 9 && x < width * 8 / 9 && y > height / 6 && y < height * 2 / 5 { color = (110, 136, 235) }
                let dx = x - width * 7 / 10, dy = y - height * 7 / 10
                if dx * dx + dy * dy < height * height / 36 { color = (244, 194, 113) }
                pixels[index] = color.2; pixels[index + 1] = color.1; pixels[index + 2] = color.0
            }
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw RendererFailure.allocation }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: pixels, bytesPerRow: width * 4)
        return texture
    }

    private static func savePNG(_ bgra: [UInt8], width: Int, height: Int, to url: URL) throws {
        guard let provider = CGDataProvider(data: Data(bgra) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw RendererFailure.allocation
        }
        try data.write(to: url)
    }

    enum RendererFailure: LocalizedError {
        case unavailable, allocation, missingShader, missingArtwork, identicalFrames, weakEdges, geometryMismatch
        var errorDescription: String? {
            switch self {
            case .unavailable: return L10n.text("Metal GPU를 사용할 수 없습니다.")
            case .allocation: return L10n.text("GPU 화면 메모리를 준비하지 못했습니다.")
            case .missingShader: return L10n.text("화면 효과 파일을 찾지 못했습니다.")
            case .missingArtwork: return L10n.text("백호 미리보기 그림을 불러오거나 확인하지 못했습니다.")
            case .identicalFrames: return L10n.text("GPU 출력 검증 실패: 블러 단계가 구별되지 않습니다.")
            case .weakEdges: return L10n.text("GPU 출력 검증 실패: 중앙과 양쪽의 흐림이 충분히 구별되지 않습니다.")
            case .geometryMismatch: return L10n.text("GPU 출력 검증 실패: 제한 각도 보정 좌표 또는 원본 밖 가림이 올바르지 않습니다.")
            }
        }
    }
}
