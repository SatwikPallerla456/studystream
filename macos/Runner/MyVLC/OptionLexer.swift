import Foundation

enum OptionLexer {
    static func parse(_ text: String) throws -> [String] {
        var values: [String] = [], token = "", quote: Character?, escaped = false
        for character in text {
            if escaped { token.append(character); escaped = false; continue }
            if character == "\\", quote != "'" { escaped = true; continue }
            if let current = quote {
                if character == current { quote = nil } else { token.append(character) }
            } else if character == "\"" || character == "'" { quote = character }
            else if character.isWhitespace { if !token.isEmpty { values.append(token); token = "" } }
            else { token.append(character) }
        }
        guard quote == nil, !escaped else { throw NSError(domain: "Options", code: 1, userInfo: [NSLocalizedDescriptionKey: "An additional libVLC option has an unmatched quote or escape."]) }
        if !token.isEmpty { values.append(token) }
        for value in values where value.hasPrefix("--") {
            let name = String(value.dropFirst(2).split(separator: "=", maxSplits: 1).first ?? "")
            guard SettingsCatalog.supportedOptions.contains(name) else { throw NSError(domain: "Options", code: 2, userInfo: [NSLocalizedDescriptionKey: "The installed VLC build does not support --\(name)."] ) }
        }
        return values
    }
}
