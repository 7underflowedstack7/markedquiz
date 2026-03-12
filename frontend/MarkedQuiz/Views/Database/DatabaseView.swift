import SwiftUI

struct DatabaseView: View {
    @State private var documents: [DocumentListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadingId: Int?
    @State private var exportFileURL: URL?
    @State private var showingShareSheet = false

    private let api: APIClientProtocol = APIClient()

    var body: some View {
        NavigationStack {
            ZStack {
                CRT.bgDeep.ignoresSafeArea()

                if isLoading && documents.isEmpty {
                    CRTLoadingView(message: "Loading documents")
                } else if let error = errorMessage, documents.isEmpty {
                    CRTErrorView(message: error) {
                        await loadDocuments()
                    }
                } else if documents.isEmpty {
                    CRTEmptyView(
                        icon: "doc.text",
                        title: "NO FILES",
                        message: "No markdown files in database."
                    )
                } else {
                    documentList
                }

                ScanlinesOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DATABASE")
                        .font(CRT.monoBold(16))
                        .foregroundStyle(CRT.orangeBright)
                        .crtGlow()
                }
            }
            .toolbarBackground(CRT.bgPanel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingShareSheet, onDismiss: {
                DownloadFileHelper.cleanupTempFile(exportFileURL)
                exportFileURL = nil
            }) {
                if let url = exportFileURL {
                    ShareSheetView(activityItems: [url])
                        .presentationDetents([.medium])
                } else {
                    EmptyView()
                }
            }
            .task {
                await loadDocuments()
            }
            .refreshable {
                await loadDocuments()
            }
        }
    }

    private var documentList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    CRTStatusDot(status: .online)
                    Text("POSTGRESQL")
                        .font(CRT.monoBold(12))
                        .foregroundStyle(CRT.textDim)
                    Spacer()
                    Text("\(documents.count) \(documents.count == 1 ? "file" : "files")")
                        .font(CRT.monoText(12))
                        .foregroundStyle(CRT.textDim)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                CRTSeparator()
                    .padding(.horizontal, 16)

                // Document rows
                ForEach(documents) { doc in
                    documentRow(doc)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(CRT.bgDeep)
    }

    private func documentRow(_ doc: DocumentListItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20))
                .foregroundStyle(CRT.cyanAccent)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title.uppercased())
                    .font(CRT.monoBold(13))
                    .foregroundStyle(CRT.orangeBright)
                    .lineLimit(1)

                Text("\(doc.wordCount) words")
                    .font(CRT.monoText(11))
                    .foregroundStyle(CRT.textDim)
            }

            Spacer()

            Button {
                Task { await downloadDocument(doc) }
            } label: {
                if downloadingId == doc.id {
                    ProgressView()
                        .tint(CRT.greenAccent)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(CRT.greenAccent)
                        .frame(width: 36, height: 36)
                }
            }
            .disabled(downloadingId != nil)
            .accessibilityLabel("Download \(doc.title)")
        }
        .padding(14)
        .crtPanel()
    }

    private func loadDocuments() async {
        isLoading = true
        do {
            documents = try await api.fetchDocuments()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func downloadDocument(_ doc: DocumentListItem) async {
        downloadingId = doc.id
        do {
            let (data, filename) = try await api.downloadDocument(id: doc.id)
            exportFileURL = try DownloadFileHelper.writeTempFile(data: data, filename: filename)
            showingShareSheet = true
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
        }
        downloadingId = nil
    }
}
