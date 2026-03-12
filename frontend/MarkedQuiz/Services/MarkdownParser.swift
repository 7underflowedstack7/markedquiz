import SwiftUI

/// Parses markdown into attributed text elements for SwiftUI rendering.
enum MarkdownElement: Identifiable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String, code: String)
    case bulletItem(text: String)
    case numberedItem(number: Int, text: String)
    case horizontalRule
    case blank

    var id: String {
        switch self {
        case .heading(let level, let text): return "h\(level)-\(text.prefix(30))"
        case .paragraph(let text): return "p-\(text.prefix(30))"
        case .codeBlock(_, let code): return "code-\(code.prefix(30))"
        case .bulletItem(let text): return "li-\(text.prefix(30))"
        case .numberedItem(let n, let text): return "ol\(n)-\(text.prefix(30))"
        case .horizontalRule: return "hr-\(UUID().uuidString.prefix(8))"
        case .blank: return "blank-\(UUID().uuidString.prefix(8))"
        }
    }
}

struct MarkdownParser: Sendable {
    func parse(_ markdown: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = markdown.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Code block
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                elements.append(.codeBlock(language: language, code: codeLines.joined(separator: "\n")))
                i += 1
                continue
            }

            // Heading
            if let headingMatch = line.firstMatch(of: /^(#{1,6})\s+(.+)/) {
                let level = headingMatch.1.count
                let text = String(headingMatch.2)
                elements.append(.heading(level: level, text: text))
                i += 1
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) &&
               line.trimmingCharacters(in: .whitespaces).count >= 3 {
                elements.append(.horizontalRule)
                i += 1
                continue
            }

            // Bullet list
            if line.firstMatch(of: /^\s*[-*+]\s+(.+)/) != nil {
                let text = String(line.replacing(/^\s*[-*+]\s+/, with: ""))
                elements.append(.bulletItem(text: text))
                i += 1
                continue
            }

            // Numbered list
            if let numMatch = line.firstMatch(of: /^\s*(\d+)\.\s+(.+)/) {
                let num = Int(numMatch.1) ?? 1
                let text = String(numMatch.2)
                elements.append(.numberedItem(number: num, text: text))
                i += 1
                continue
            }

            // Blank line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                elements.append(.blank)
                i += 1
                continue
            }

            // Table — lines starting with |
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                var tableLines: [String] = [line]
                i += 1
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[i])
                    i += 1
                }
                elements.append(.codeBlock(language: "table", code: tableLines.joined(separator: "\n")))
                continue
            }

            // Paragraph — collect consecutive non-empty lines
            var paragraphLines: [String] = [line]
            i += 1
            while i < lines.count {
                let nextLine = lines[i]
                if nextLine.trimmingCharacters(in: .whitespaces).isEmpty ||
                   nextLine.hasPrefix("#") ||
                   nextLine.hasPrefix("```") ||
                   nextLine.hasPrefix("**") ||
                   nextLine.trimmingCharacters(in: .whitespaces).hasPrefix("|") ||
                   nextLine.firstMatch(of: /^\s*[-*+]\s+/) != nil ||
                   nextLine.firstMatch(of: /^\s*\d+\.\s+/) != nil {
                    break
                }
                paragraphLines.append(nextLine)
                i += 1
            }
            elements.append(.paragraph(text: paragraphLines.joined(separator: " ")))
        }

        return elements
    }
}
