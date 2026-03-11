import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @State private var viewModel = LibraryViewModel()
    @State private var showingAddSheet = false
    @State private var showingFilePicker = false
    @State private var newTitle = ""
    @State private var newContent = ""

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
            .task {
                await viewModel.loadDocuments()
            }
            .refreshable {
                await viewModel.loadDocuments()
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
        }
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
                    DocumentRow(document: doc)
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

                        CRTSeparator()

                        Text("OR PASTE CONTENT")
                            .font(CRT.monoText(12))
                            .foregroundStyle(CRT.textDim)

                        CRTButton(title: "UPLOAD", icon: "arrow.up.doc") {
                            Task {
                                await viewModel.uploadContent(title: newTitle, content: newContent)
                                newTitle = ""
                                newContent = ""
                                showingAddSheet = false
                            }
                        }
                        .disabled(newTitle.isEmpty || newContent.isEmpty)
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
            }
        }
        .presentationDetents([.large])
    }
}

struct DocumentRow: View {
    let document: DocumentListItem

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
    }
}
