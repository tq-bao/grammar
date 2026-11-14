import Foundation

/// Một token (từ hoặc dấu câu) cùng vị trí của nó trong chuỗi gốc.
public struct TextToken: Equatable, Sendable {
    public let text: String
    public let range: Range<String.Index>
}

/// Tách câu thành từ và dấu câu, bỏ qua khoảng trắng.
///
/// - Từ: chuỗi chữ/số liền nhau, cho phép dấu nháy và gạch nối *ở giữa* (don't, well-known).
/// - Mỗi ký tự còn lại (không phải khoảng trắng) là một token dấu câu riêng.
public enum WordTokenizer {
    public static func tokenize(_ text: String) -> [TextToken] {
        var tokens: [TextToken] = []
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]

            if char.isWhitespace {
                index = text.index(after: index)
                continue
            }

            if isWordChar(char) {
                let start = index
                var end = text.index(after: index)
                while end < text.endIndex {
                    let c = text[end]
                    if isWordChar(c) {
                        end = text.index(after: end)
                    } else if isInnerJoiner(c) {
                        // Chỉ nhận nháy/gạch nối khi phía sau tiếp tục là chữ.
                        let next = text.index(after: end)
                        if next < text.endIndex, isWordChar(text[next]) {
                            end = text.index(after: next)
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                tokens.append(TextToken(text: String(text[start..<end]), range: start..<end))
                index = end
            } else {
                let end = text.index(after: index)
                tokens.append(TextToken(text: String(char), range: index..<end))
                index = end
            }
        }
        return tokens
    }

    private static func isWordChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }

    private static func isInnerJoiner(_ c: Character) -> Bool {
        c == "'" || c == "’" || c == "-"
    }
}
