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

}
