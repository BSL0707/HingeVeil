import XCTest
@testable import HingeVeilCore

final class LocalizationTests: XCTestCase {
    func testCatalogsHaveMatchingKeysAndNoEmptyValues() {
        let en = L10n.catalog(for: .english), ko = L10n.catalog(for: .korean)
        XCTAssertGreaterThanOrEqual(en.count, 72)
        XCTAssertEqual(Set(en.keys), Set(ko.keys))
        for key in en.keys {
            XCTAssertFalse(en[key]!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertEqual(ko[key], key)
            XCTAssertFalse(en[key]!.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) })
        }
    }
    func testInterpolationTokensMatchInBothLanguages() throws {
        let token = try NSRegularExpression(pattern: #"\{[0-9]+\}"#)
        func tokens(_ value: String) -> [String] {
            token.matches(in: value, range: NSRange(value.startIndex..., in: value))
                .map { (value as NSString).substring(with: $0.range) }.sorted()
        }
        for (key, translated) in L10n.catalog(for: .english) {
            XCTAssertEqual(tokens(key), tokens(translated), key)
        }
    }
    func testSystemLanguageFallbackAndExplicitChoices() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ko-KR", "en"]), .korean)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr", "ko"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["ko"]), .english)
    }
    func testExistingMessageRendersInEitherLanguageAndPreservesArguments() {
        let message: AppText = "화면 연결 완료 · 덮개를 \(93)° 이상 열어 준비한 뒤 내리세요."
        XCTAssertEqual(message.key, "화면 연결 완료 · 덮개를 {0}° 이상 열어 준비한 뒤 내리세요.")
        XCTAssertTrue(message.localized(in: .english).contains("at least 93°"))
        XCTAssertTrue(message.localized(in: .korean).contains("93° 이상"))
        let external = AppText("화면 연결 실패: {0}", arguments: ["example {1}"])
        XCTAssertEqual(external.localized(in: .english), "Display connection failed: example {1}")
    }
    func testBothManualsCoverEscapePrivacyAndSafetyLimits() {
        for language in [AppLanguage.korean, .english] {
            let manual = L10n.manual(language: language)
            XCTAssertGreaterThan(manual.count, 2000)
            for term in ["Control + Option + Command + Esc", "15", "0.18", "0.24", "ScreenCaptureKit", "Gatekeeper"] {
                XCTAssertTrue(manual.contains(term), term)
            }
        }
    }
}
