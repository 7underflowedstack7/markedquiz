import SwiftUI

@MainActor
@Observable
final class ReaderViewModel {
    var document: DocumentDetail?
    var elements: [MarkdownElement] = []
    var isLoading = false
    var errorMessage: String?
    var fontSize: CGFloat = 14

    private let api: APIClientProtocol
    private let parser = MarkdownParser()

    init(api: APIClientProtocol = APIClient()) {
        self.api = api
    }

    func loadDocument(id: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            let doc = try await api.fetchDocument(id: id)
            document = doc
            // Strip ## Questions and everything after for the reader
            let readerContent = Self.stripQuizSections(doc.content)
            elements = parser.parse(readerContent)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    static func stripQuizSections(_ content: String) -> String {
        // Remove everything from "## Questions" onward
        if let range = content.range(of: "\n## Questions", options: .caseInsensitive) {
            return String(content[content.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content
    }

    func increaseFontSize() {
        if fontSize < 24 { fontSize += 2 }
    }

    func decreaseFontSize() {
        if fontSize > 10 { fontSize -= 2 }
    }
}
