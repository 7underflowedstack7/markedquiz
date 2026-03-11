import SwiftUI

struct DocumentDetailView: View {
    let documentId: Int
    @State private var readerVM = ReaderViewModel()
    @State private var quizVM = QuizViewModel()
    @State private var showingQuiz = false
    @State private var showingReader = false

    var body: some View {
        ZStack {
            CRT.bgDeep.ignoresSafeArea()

            if readerVM.isLoading {
                CRTLoadingView(message: "Loading document")
            } else if let error = readerVM.errorMessage {
                CRTErrorView(message: error) {
                    await readerVM.loadDocument(id: documentId)
                }
            } else if let document = readerVM.document {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Document info header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(document.title)
                                .font(CRT.monoBold(22))
                                .foregroundStyle(CRT.orangeBright)
                                .crtGlow()

                            HStack(spacing: 16) {
                                Label("\(document.content.split(separator: " ").count) words", systemImage: "text.word.spacing")
                                Label(String(document.createdAt.prefix(10)), systemImage: "calendar")
                            }
                            .font(CRT.monoText(12))
                            .foregroundStyle(CRT.textDim)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        CRTSeparator()
                            .padding(.horizontal, 20)

                        // Action buttons
                        VStack(spacing: 12) {
                            actionButton(
                                icon: "book.fill",
                                title: "READ DOCUMENT",
                                subtitle: "Open in markdown reader",
                                color: CRT.cyanAccent
                            ) {
                                showingReader = true
                            }

                            actionButton(
                                icon: "questionmark.circle.fill",
                                title: "GENERATE QUIZ",
                                subtitle: "Create quiz from content",
                                color: CRT.orangeBright
                            ) {
                                showingQuiz = true
                                Task {
                                    await quizVM.generateQuiz(documentId: documentId)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        CRTSeparator()
                            .padding(.horizontal, 20)

                        // Content preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PREVIEW")
                                .font(CRT.monoBold(12))
                                .foregroundStyle(CRT.textDim)

                            Text(document.content.prefix(500) + (document.content.count > 500 ? "..." : ""))
                                .font(CRT.monoText(12))
                                .foregroundStyle(CRT.orangeDim)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }

                ScanlinesOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CRT.bgPanel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $showingReader) {
            ReaderView(viewModel: readerVM)
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            QuizView(viewModel: quizVM, documentId: documentId)
        }
        .task {
            await readerVM.loadDocument(id: documentId)
        }
    }

    private func actionButton(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CRT.monoBold(14))
                        .foregroundStyle(color)
                    Text(subtitle)
                        .font(CRT.monoText(11))
                        .foregroundStyle(CRT.textDim)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(color.opacity(0.5))
            }
            .padding(14)
            .crtPanel()
        }
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
