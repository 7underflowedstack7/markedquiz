import Foundation

@Observable
@MainActor
final class FileService {
    private(set) var files: [FileRecord] = []
    private(set) var folders: [String] = []
    private(set) var isLoading = false
    var error: String?

    private let baseURL = "https://markedquiz.onrender.com/api/files"

    // MARK: - Fetch

    func fetchFiles(extension ext: String? = nil, folder: String? = nil, token: String?) async {
        guard let token else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = []
        if let ext { queryItems.append(.init(name: "extension", value: ext)) }
        if let folder { queryItems.append(.init(name: "folder", value: folder)) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Failed to fetch files"
                return
            }
            files = try JSONDecoder.iso8601.decode([FileRecord].self, from: data)
            folders = Array(Set(files.map(\.folder).filter { !$0.isEmpty })).sorted()
        } catch {
            self.error = "Failed to decode files"
        }
    }

    // MARK: - Create File

    func createFile(filename: String, content: String, folder: String, token: String?) async -> Bool {
        guard let token else { return false }
        error = nil

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = FileCreate(filename: filename, content: content, folder: folder)
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
                error = "Failed to create file"
                return false
            }
            await fetchFiles(token: token)
            return true
        } catch {
            self.error = "Network error"
            return false
        }
    }

    // MARK: - Delete File

    func deleteFile(id: Int, token: String?) async -> Bool {
        guard let token else { return false }
        error = nil

        var request = URLRequest(url: URL(string: "\(baseURL)/\(id)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Failed to delete file"
                return false
            }
            files.removeAll { $0.id == id }
            folders = Array(Set(files.map(\.folder).filter { !$0.isEmpty })).sorted()
            return true
        } catch {
            self.error = "Network error"
            return false
        }
    }

    // MARK: - Delete Folder

    func deleteFolder(name: String, token: String?) async -> Bool {
        guard let token else { return false }
        error = nil

        var request = URLRequest(url: URL(string: "\(baseURL)/folder/\(name)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Failed to delete folder"
                return false
            }
            await fetchFiles(token: token)
            return true
        } catch {
            self.error = "Network error"
            return false
        }
    }

    // MARK: - Get File Detail

    func getFile(id: Int, token: String?) async -> FileDetail? {
        guard let token else { return nil }

        var request = URLRequest(url: URL(string: "\(baseURL)/\(id)")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder.iso8601.decode(FileDetail.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - Update File

    /// PUT /api/files/{id} — update content and/or filename.
    /// Returns the updated FileDetail on success, nil on failure.
    func updateFile(id: Int, content: String? = nil, filename: String? = nil, token: String?) async -> FileDetail? {
        guard let token else { return nil }
        error = nil

        var request = URLRequest(url: URL(string: "\(baseURL)/\(id)")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = FileUpdatePayload(filename: filename, content: content)
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Failed to update file"
                return nil
            }
            let updated = try JSONDecoder.iso8601.decode(FileDetail.self, from: data)
            // Refresh the local file list so RecordsView reflects the change
            await fetchFiles(token: token)
            return updated
        } catch {
            self.error = "Network error"
            return nil
        }
    }

    // MARK: - Computed

    var fileCount: Int { files.count }
    var noteCount: Int { files.filter { $0.extension == "md" }.count }
}
