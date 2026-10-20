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
    private enum HelpSheet: String, Identifiable { case manual, permissions; var id: String { rawValue } }
    @ObservedObject var controller: AppController
    @State private var helpSheet: HelpSheet?

    init(controller: AppController, showManual: Bool = false, showPermissionHelp: Bool = false) {
        self.controller = controller
        _helpSheet = State(initialValue: showPermissionHelp ? .permissions : (showManual ? .manual : nil))
    }
    private func t(_ key: String) -> String { L10n.text(key, language: controller.language) }
    private func m(_ message: AppText) -> String { message.localized(in: controller.language) }

    var body: some View {
        ScrollView {
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(t(controller.permission ? "화면 권한 확인됨" : "화면 권한 확인 필요"),
                          systemImage: controller.permission ? "checkmark.shield" : "exclamationmark.shield")
                        .foregroundStyle(controller.permission ? Color.green : Color.orange)
                    Spacer()
                    Button(t("화면 권한 요청")) { controller.requestPermission() }
                        .disabled(controller.isReviewMode || controller.recoveryInProgress || !controller.permissionState.canRequest)
                    Button(t("권한 다시 확인")) { controller.refreshPermission(announce: true) }
                        .disabled(controller.isReviewMode || controller.recoveryInProgress || controller.permissionState.requestInFlight)
                    Button(t("설정 열기")) { controller.openPermissionSettings() }.disabled(controller.isReviewMode)
                }
                Text(m(controller.permissionState.guidance)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(t("권한 복구…")) { controller.requestPermissionRecovery() }
                        .accessibilityLabel(t("권한 복구…"))
                        .disabled(controller.isReviewMode || controller.recoveryInProgress || controller.permissionState.requestInFlight)
                    Button(t("권한·재시작 도움말")) { helpSheet = .permissions }
                }
                if let notice = controller.recoveryNotice {
                    Text(m(notice)).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(12).background(Color.secondary.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
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
                    .toggleStyle(.switch).disabled(controller.isReviewMode || controller.recoveryInProgress)
            }
            Text(m(controller.status)).font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            HStack {
                Button(t("30% 접힘 테스트 · 2초")) { controller.runTest() }
                    .accessibilityLabel(t("30% 접힘 테스트 · 2초")).disabled(controller.isReviewMode || controller.recoveryInProgress)
                Spacer()
                Button(t("사용 설명서")) { helpSheet = .manual }.accessibilityLabel(t("사용 설명서"))
            }
            Text(t("화면 클릭 · ⌃⌥⌘Esc로 해제 / 15초 안전 제한 / 화면·소리 저장 및 전송 없음"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(26)
        }.frame(width: 720)
        .environment(\.locale, Locale(identifier: controller.language.resolved().rawValue))
        .sheet(item: $helpSheet) { sheet in
            VStack(alignment: .leading, spacing: 16) {
                Text(t(sheet == .manual ? "HingeVeil 사용 설명서" : "권한·재시작 도움말")).font(.title2.bold())
                ScrollView {
                    if sheet == .manual {
                    Text(L10n.manual(language: controller.language))
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(t("1. 설정에서 HingeVeil만 허용한 뒤 앱으로 돌아와 ‘권한 다시 확인’을 누르세요. 앱은 돌아올 때도 권한을 다시 읽으며 같은 실행 중에 시스템 요청을 반복하지 않습니다."))
                            Text(t("2. 허용했는데도 미확인이면 ‘앱 종료’를 누르고 응용 프로그램 폴더의 HingeVeil을 다시 여세요. macOS가 ‘종료 및 다시 열기’를 제공하면 사용하세요. 다시 허용해도 정상 적용을 보장할 수는 없습니다."))
                            Text(t("3. 구버전에서 업데이트했다면 임시 서명이 달라 기존 허용 기록과 충돌할 수 있습니다. 다른 복사본과 덮개 효과 앱을 종료하고 응용 프로그램에 한 버전만 두세요. 동일한 DMG를 다시 받는 것만으로 서명은 바뀌지 않습니다."))
                            Text(t("4. 계속 미확인이면 ‘권한 복구…’를 누르고 확인창의 범위를 읽은 뒤 동의하세요. 앱이 종료된 뒤 HingeVeil의 화면 권한만 초기화하고 같은 앱을 다시 엽니다. 터미널은 필요하지 않습니다."))
                            Text(t("복구 후에도 시스템 허용은 직접 눌러야 합니다. 앱은 권한을 자동 허용하거나 복구를 자동 반복하지 않습니다. Gatekeeper·SIP를 끄거나 격리 속성을 지우지 마세요."))
                        }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }
                }
                HStack {
                    if sheet == .permissions {
                        Button(t("설정 열기")) { controller.openPermissionSettings() }.disabled(controller.isReviewMode)
                        Button(t("앱 종료")) { controller.quitForPermissionRestart() }.disabled(controller.isReviewMode)
                    }
                    Spacer()
                    Button(t("닫기")) { helpSheet = nil }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 640, height: 560)
        }
    }
}
