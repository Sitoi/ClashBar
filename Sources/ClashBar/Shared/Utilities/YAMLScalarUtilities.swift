import Foundation

func stripYAMLInlineComment(_ value: String) -> String {
    var inSingleQuote = false
    var inDoubleQuote = false
    var isEscaped = false
    var result = ""

    for char in value {
        if isEscaped {
            result.append(char)
            isEscaped = false
            continue
        }

        if char == "\\", inDoubleQuote {
            result.append(char)
            isEscaped = true
            continue
        }

        if char == "'", !inDoubleQuote {
            inSingleQuote.toggle()
            result.append(char)
            continue
        }

        if char == "\"", !inSingleQuote {
            inDoubleQuote.toggle()
            result.append(char)
            continue
        }

        if char == "#", !inSingleQuote, !inDoubleQuote {
            break
        }

        result.append(char)
    }

    return result
}

func normalizedYAMLScalar(_ value: String?) -> String? {
    guard var value else { return nil }
    value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }

    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
        value.removeFirst()
        value.removeLast()
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    guard !value.isEmpty else { return nil }
    if value == "~" || value.lowercased() == "null" {
        return nil
    }
    return value
}
