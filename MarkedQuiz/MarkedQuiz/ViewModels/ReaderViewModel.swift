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
            elements = parser.parse(doc.content)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func increaseFontSize() {
        if fontSize < 24 { fontSize += 2 }
    }

    func decreaseFontSize() {
        if fontSize > 10 { fontSize -= 2 }
    }
}
