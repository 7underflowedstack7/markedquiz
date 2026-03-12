import SwiftUI

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()

@State private var showErrorBanner = false
    @State private var downloadFileURL: URL?
    @State private var showingShareSheet = false
    @State private var downloadingDocumentIDs: Set<Int> = []

    var body: some View {
        NavigationStack {
            ZStack {
                CRT.bgDeep.ignoresSafeArea()

                if viewModel.isLoading && viewModel.documents.isEmpty {
                    CRTLoadingView(message: "Loading documents")
                } else if let error = viewModel.errorMessage, viewModel.documents.isEmpty {
                    CRTErrorView(message: error) {
                        await viewModel.loadDocuments()
                    }
                } else if viewModel.documents.isEmpty {
                    CRTEmptyView(
                        icon: "doc.text",
                        title: "NO DOCUMENTS",
                        message: "No documents available yet."
                    )
                } else {
                    documentList
                }

                ScanlinesOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Error banner overlay for non-empty state errors
                if showErrorBanner, let error = viewModel.errorMessage {
                    VStack {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(CRT.redAccent)
                            Text(error)
                                .font(CRT.monoText(12))
                                .foregroundStyle(CRT.orangeBright)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                withAnimation { showErrorBanner = false }
                                viewModel.errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(CRT.orangeDim)
                            }
                        }
                        .padding(12)
                        .background(CRT.bgPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(CRT.redAccent.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MARKED//QUIZ")
                        .font(CRT.monoBold(16))
                        .foregroundStyle(CRT.orangeBright)
                        .crtGlow()
                }
            }
            .toolbarBackground(CRT.bgPanel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.loadDocuments()
            }
            .onAppear {
                // Refresh list when returning from detail
                if !viewModel.documents.isEmpty {
                    Task { await viewModel.loadDocuments() }
                }
            }
            .refreshable {
                await viewModel.loadDocuments()
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                if newValue != nil && !viewModel.documents.isEmpty {
                    withAnimation { showErrorBanner = true }
                }
            }
            .sheet(isPresented: $showingShareSheet, onDismiss: {
                DownloadFileHelper.cleanupTempFile(downloadFileURL)
                downloadFileURL = nil
            }) {
                if let url = downloadFileURL {
                    ShareSheetView(activityItems: [url])
                        .presentationDetents([.medium])
                }
            }
        }
    }

    private func downloadDocument(_ doc: DocumentListItem) async {
        downloadingDocumentIDs.insert(doc.id)
        do {
            let (data, filename) = try await APIClient().downloadDocument(id: doc.id)
            downloadFileURL = try DownloadFileHelper.writeTempFile(data: data, filename: filename)
            showingShareSheet = true
        } catch {
            viewModel.errorMessage = "Download failed: \(error.localizedDescription)"
        }
        downloadingDocumentIDs.remove(doc.id)
    }

    private var documentList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Terminal header
                HStack(spacing: 8) {
                    CRTStatusDot(status: .online)
                    Text("LIBRARY")
                        .font(CRT.monoBold(12))
                        .foregroundStyle(CRT.textDim)
                    Spacer()
                    Text("\(viewModel.documents.count) files")
                        .font(CRT.monoText(12))
                        .foregroundStyle(CRT.textDim)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                CRTSeparator()
                    .padding(.horizontal, 16)

                ForEach(viewModel.documents) { doc in
                    DocumentRow(
                        document: doc,
                        isDownloading: downloadingDocumentIDs.contains(doc.id),
                        onDownload: {
                            Task {
                                await downloadDocument(doc)
                            }
                        }
                    )
                }
            }
            .padding(.bottom, 20)
        }
        .background(CRT.bgDeep)
    }

}

struct DocumentRow: View {
    let document: DocumentListItem
    var isDownloading: Bool = false
    var onDownload: (() -> Void)?

    var body: some View {
        NavigationLink {
            DocumentDetailView(documentId: document.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(CRT.orangeDim)

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(CRT.monoBold(14))
                        .foregroundStyle(CRT.orangeBright)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Text("\(document.wordCount) words")
                            .font(CRT.monoText(11))
                            .foregroundStyle(CRT.textDim)

                        Text(document.createdAt.prefix(10))
                            .font(CRT.monoText(11))
                            .foregroundStyle(CRT.textDim)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(CRT.monoText(12))
                    .foregroundStyle(CRT.orangeFaint)
            }
            .padding(14)
            .crtPanel()
            .padding(.horizontal, 16)
        }
        .accessibilityLabel("\(document.title), \(document.wordCount) words")
        .contextMenu {
            Button {
                onDownload?()
            } label: {
                Label("Download", systemImage: "arrow.down.doc")
            }
            .disabled(isDownloading)

        }
    }
}
