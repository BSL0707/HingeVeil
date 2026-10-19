import AppKit
import MetalKit
import SwiftUI
import HingeVeilCore

private struct VeilPreview: NSViewRepresentable {
    let angle: Double
    let options: VeilOptions

    final class Coordinator {
        var renderer: VeilRenderer?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        do {
            let renderer = try VeilRenderer(previewArtwork: true)
            context.coordinator.renderer = renderer
            renderer.configure(view)
            renderer.update(angle: angle, options: options, reset: true)
        } catch { view.clearColor = MTLClearColorMake(0.08, 0.12, 0.15, 1) }
        return view
    }
    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.renderer?.update(angle: angle, options: options)
    }
    static func dismantleNSView(_ nsView: MTKView, coordinator: Coordinator) {
        nsView.isPaused = true; nsView.delegate = nil; coordinator.renderer = nil
    }
}

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @State private var showManual = false

    init(controller: AppController, showManual: Bool = false) {
        self.controller = controller
        _showManual = State(initialValue: showManual)
    }
    private func t(_ key: String) -> String { L10n.text(key, language: controller.language) }
    private func m(_ message: AppText) -> String { message.localized(in: controller.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: IconArtwork.image(size: 56))
                    .resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("HingeVeil").font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(t("힌지베일 · 화면은 머무르고 덮개는 부드럽게"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(m("개발 미리보기 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(t("언어"))
                Picker("", selection: $controller.language) {
                    Text(t("시스템 설정 따름")).tag(AppLanguage.system)
                    Text("한국어").tag(AppLanguage.korean)
                    Text("English").tag(AppLanguage.english)
                }.pickerStyle(.segmented).labelsHidden()
                    .accessibilityLabel(t("언어")).frame(width: 330)
                Spacer()
            }
            VeilPreview(angle: controller.previewAngle, options: controller.options)
                .frame(width: 480, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomLeading) {
                    Text(t("백호 그림 미리보기 · 실제 화면을 읽지 않습니다"))
                        .font(.caption).padding(8).background(.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 8)).padding(12)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            HStack {
                Text(t("미리보기 각도")).frame(width: 100, alignment: .leading)
                Slider(value: $controller.previewAngle, in: 15...120)
                    .tint(Color(red: 0.22, green: 0.75, blue: 0.64))
                Text("\(Int(controller.previewAngle))°").monospacedDigit().frame(width: 42)
            }
            HStack(spacing: 24) {
                Picker(t("효과 시작 각도"), selection: $controller.startAngle) {
                    ForEach([85.0, 90, 95, 100], id: \.self) { Text("\(Int($0))°").tag($0) }
                }
                Picker(t("블러 강도"), selection: $controller.blurLevel) {
                    ForEach(1...4, id: \.self) { Text(m("\($0)단계")).tag($0) }
                }
            }
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(controller.angle.map { m("덮개 각도 \(Int($0.rounded()))°") } ?? t("덮개 각도 확인 중"),
                          systemImage: "angle").font(.headline)
                    Text(m(controller.sensorText)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle(t("실제 덮개 효과"), isOn: Binding(get: { controller.enabled }, set: { controller.setEnabled($0) }))
                    .toggleStyle(.switch).disabled(controller.isReviewMode)
            }
            Text(m(controller.status)).font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            HStack {
                Button(t("화면 권한 확인")) { controller.requestPermission() }
                    .accessibilityLabel(t("화면 권한 확인")).disabled(controller.isReviewMode)
                Button(t("30% 접힘 테스트 · 2초")) { controller.runTest() }
                    .accessibilityLabel(t("30% 접힘 테스트 · 2초")).disabled(controller.isReviewMode)
                Spacer()
                Button(t("사용 설명서")) { showManual = true }.accessibilityLabel(t("사용 설명서"))
            }
            Text(t("화면 클릭 · ⌃⌥⌘Esc로 해제 / 15초 안전 제한 / 화면·소리 저장 및 전송 없음"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(26).frame(width: 720)
        .environment(\.locale, Locale(identifier: controller.language.resolved().rawValue))
        .sheet(isPresented: $showManual) {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("HingeVeil 사용 설명서")).font(.title2.bold())
                ScrollView {
                    Text(L10n.manual(language: controller.language))
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
                Button(t("닫기")) { showManual = false }.keyboardShortcut(.defaultAction)
            }.padding(24).frame(width: 640, height: 560)
        }
    }
}
