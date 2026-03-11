import SwiftUI

@MainActor
@Observable
final class LibraryViewModel {
    var documents: [DocumentListItem] = []
    var isLoading = false
    var errorMessage: String?
    var showingImporter = false

    private let api: APIClientProtocol

    init(api: APIClientProtocol = APIClient()) {
        self.api = api
    }

    func loadDocuments() async {
        isLoading = true
        errorMessage = nil
        do {
            documents = try await api.fetchDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func uploadContent(title: String, content: String) async {
        do {
            _ = try await api.uploadDocument(title: title, content: content)
            await loadDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteDocument(id: Int) async {
        do {
            try await api.deleteDocument(id: id)
            documents.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
