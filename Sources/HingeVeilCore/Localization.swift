import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, korean = "ko", english = "en"
    public var id: String { rawValue }

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        return preferredLanguages.first?.lowercased().hasPrefix("ko") == true ? .korean : .english
    }
}

/// Store keys and interpolation arguments, not translated snapshots. Existing
/// status and sensor messages can therefore change language without a restart.
public struct AppText: Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public let key: String
    public let arguments: [String]

    public init(_ key: String, arguments: [String] = []) {
        self.key = key; self.arguments = arguments
    }
    public init(stringLiteral value: String) { self.init(value) }
    public init(stringInterpolation: StringInterpolation) {
        self.init(stringInterpolation.key, arguments: stringInterpolation.arguments)
    }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments = [String]()
        public init(literalCapacity: Int, interpolationCount: Int) { key.reserveCapacity(literalCapacity) }
        public mutating func appendLiteral(_ literal: String) { key += literal }
        public mutating func appendInterpolation<T>(_ value: T) {
            key += "{\(arguments.count)}"
            arguments.append(String(describing: value))
        }
    }
    public func localized(in language: AppLanguage = L10n.selectedLanguage) -> String {
        let template = L10n.text(key, language: language)
        // Substitute only tokens from the template, never tokens inside values.
        var output = "", cursor = template.startIndex
        while cursor < template.endIndex {
            if template[cursor] == "{", let end = template[cursor...].firstIndex(of: "}"),
               let index = Int(template[template.index(after: cursor)..<end]), arguments.indices.contains(index) {
                output += arguments[index]; cursor = template.index(after: end)
            } else { output.append(template[cursor]); cursor = template.index(after: cursor) }
        }
        return output
    }
}

public enum L10n {
    public static let preferenceKey = "interfaceLanguage"
    public static var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .system
    }

    private static func resourceURL(_ name: String, extension ext: String, language: AppLanguage? = nil) -> URL? {
        if let language {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "\(language.rawValue).lproj") { return url }
        } else if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        #if !VEIL_PACKAGED
        if let language {
            return Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "\(language.rawValue).lproj")
        }
        return Bundle.module.url(forResource: name, withExtension: ext)
        #else
        return nil
        #endif
    }

    public static func catalog(for language: AppLanguage) -> [String: String] {
        guard let url = resourceURL("Localizable", extension: "strings", language: language.resolved()),
              let data = try? Data(contentsOf: url),
              let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let strings = object as? [String: String] else { return [:] }
        return strings
    }
    private static let english = catalog(for: .english)
    private static let korean = catalog(for: .korean)

    public static func text(_ key: String, language: AppLanguage = selectedLanguage) -> String {
        (language.resolved() == .korean ? korean : english)[key] ?? key
    }
    public static func manual(language: AppLanguage = selectedLanguage) -> String {
        let code = language.resolved().rawValue
        guard let url = resourceURL("Manual.\(code)", extension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return code == "ko" ? "설명서 파일을 찾지 못했습니다." : "The manual could not be found."
        }
        return contents
    }
}

