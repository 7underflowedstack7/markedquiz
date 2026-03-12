import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var showingAddSheet = false
    @State private var showingFilePicker = false
    @State private var newTitle = ""
    @State private var newContent = ""
    @State private var documentToDelete: DocumentListItem?
    @State private var showingDeleteConfirmation = false
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
                        message: "Upload a markdown file to get started. Import .md files to create quizzes.",
                        actionTitle: "ADD DOCUMENT",
                        action: { showingAddSheet = true }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(CRT.orangeBright)
                    }
                    .accessibilityLabel(String(localized: "Add document"))
                }
            }
            .toolbarBackground(CRT.bgPanel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                addDocumentSheet
            }
            .confirmationDialog(
                "Delete Document",
                isPresented: $showingDeleteConfirmation,
                presenting: documentToDelete
            ) { doc in
                Button("Delete \"\(doc.title)\"", role: .destructive) {
                    Task {
                        await viewModel.deleteDocument(id: doc.id)
                        if let error = viewModel.errorMessage {
                            withAnimation { showErrorBanner = true }
                            _ = error
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { doc in
                Text("This will permanently delete \"\(doc.title)\" and cannot be undone.")
            }
            .task {
                await viewModel.loadDocuments()
            }
            .onAppear {
                // Refresh list when returning from detail (e.g., after a delete)
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
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task {
                        for url in urls {
                            guard url.startAccessingSecurityScopedResource() else { continue }
                            defer { url.stopAccessingSecurityScopedResource() }
                            if let data = try? Data(contentsOf: url),
                               let content = String(data: data, encoding: .utf8) {
                                let title = url.deletingPathExtension().lastPathComponent
                                await viewModel.uploadContent(title: title, content: content)
                            }
                        }
                    }
                case .failure:
                    break
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
                        },
                        onDelete: {
                            documentToDelete = doc
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.bottom, 20)
        }
        .background(CRT.bgDeep)
    }

    private var addDocumentSheet: some View {
        NavigationStack {
            ZStack {
                CRT.bgDeep.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("NEW DOCUMENT")
                            .font(CRT.monoBold(18))
                            .foregroundStyle(CRT.orangeBright)
                            .crtGlow()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("TITLE")
                                .font(CRT.monoText(12))
                                .foregroundStyle(CRT.textDim)
                            TextField("Document title", text: $newTitle)
                                .font(CRT.monoText(14))
                                .foregroundStyle(CRT.orangeGlow)
                                .padding(12)
                                .background(CRT.bgPanel)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(CRT.orangeFaint, lineWidth: 1)
                                )
                                .accessibilityLabel(String(localized: "Document title"))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("MARKDOWN CONTENT")
                                .font(CRT.monoText(12))
                                .foregroundStyle(CRT.textDim)

                            TextEditor(text: $newContent)
                                .font(CRT.monoText(13))
                                .foregroundStyle(CRT.orangeGlow)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 300)
                                .padding(12)
                                .background(CRT.bgPanel)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(CRT.orangeFaint, lineWidth: 1)
                                )
                                .accessibilityLabel(String(localized: "Markdown content"))
                        }

                        CRTButton(title: "IMPORT .MD FILE", icon: "folder") {
                            showingAddSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingFilePicker = true
                            }
                        }
                        .frame(maxWidth: .infinity)

                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingAddSheet = false
                    } label: {
                        Text("Cancel")
                            .font(CRT.monoText(14))
                            .foregroundStyle(CRT.orangeDim)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.uploadContent(title: newTitle, content: newContent)
                            newTitle = ""
                            newContent = ""
                            showingAddSheet = false
                        }
                    } label: {
                        Text("Create")
                            .font(CRT.monoBold(14))
                            .foregroundStyle(CRT.orangeBright)
                    }
                    .disabled(newTitle.isEmpty || newContent.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct DocumentRow: View {
    let document: DocumentListItem
    var isDownloading: Bool = false
    var onDownload: (() -> Void)?
    var onDelete: (() -> Void)?

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

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
