import SwiftUI

struct QuizView: View {
    @Bindable var viewModel: QuizViewModel
    let documentId: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CRT.bgDeep.ignoresSafeArea()

                if viewModel.isLoading {
                    CRTLoadingView(message: "Generating quiz")
                } else if let error = viewModel.errorMessage, viewModel.quiz == nil {
                    CRTErrorView(message: error) {
                        await viewModel.generateQuiz(documentId: documentId)
                    }
                } else if viewModel.showingResults, let result = viewModel.quizResult {
                    QuizResultsView(result: result) {
                        viewModel.reset()
                        dismiss()
                    } onRetry: {
                        Task {
                            await viewModel.generateQuiz(documentId: documentId)
                        }
                    }
                } else if let question = viewModel.currentQuestion {
                    questionContent(question)
                }

                ScanlinesOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        viewModel.reset()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CRT.orangeDim)
                    }
                    .accessibilityLabel(String(localized: "Close quiz"))
                }

                ToolbarItem(placement: .principal) {
                    Text(viewModel.quiz?.title ?? "QUIZ")
                        .font(CRT.monoBold(14))
                        .foregroundStyle(CRT.orangeBright)
                        .lineLimit(1)
                }
            }
            .toolbarBackground(CRT.bgPanel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func questionContent(_ question: Question) -> some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: 4) {
                HStack {
                    Text("QUESTION \(viewModel.currentQuestionIndex + 1)/\(viewModel.totalQuestions)")
                        .font(CRT.monoBold(11))
                        .foregroundStyle(CRT.textDim)
                    Spacer()
                    Text("FREE RESPONSE")
                        .font(CRT.monoText(11))
                        .foregroundStyle(CRT.cyanAccent)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(CRT.bgLine)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(CRT.orangeBright)
                            .frame(width: geo.size.width * viewModel.progress, height: 4)
                            .shadow(color: CRT.orangeBright.opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Question text
                    Text(question.question)
                        .font(CRT.monoText(16))
                        .foregroundStyle(CRT.orangeGlow)
                        .crtGlow(radius: 2)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)

                    CRTSeparator()
                        .padding(.horizontal, 20)

                    // Free response text input
                    freeResponseInput
                }
                .padding(.bottom, 100)
            }

            Spacer()

            // Navigation buttons
            navigationBar
        }
    }

    private var freeResponseInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR ANSWER")
                .font(CRT.monoText(11))
                .foregroundStyle(CRT.textDim)

            HStack(alignment: .top) {
                Text("> ")
                    .font(CRT.monoText(16))
                    .foregroundStyle(CRT.cyanAccent)
                    .padding(.top, 8)

                TextEditor(text: $viewModel.fillBlankText)
                    .font(CRT.monoText(14))
                    .foregroundStyle(CRT.orangeGlow)
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Type your answer"))
            }
            .padding(14)
            .background(CRT.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(CRT.orangeFaint, lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }

    private var navigationBar: some View {
        HStack(spacing: 16) {
            if viewModel.currentQuestionIndex > 0 {
                CRTSecondaryButton(title: "PREV", icon: "chevron.left", color: CRT.orangeDim) {
                    withAnimation { viewModel.previousQuestion() }
                }
            }

            Spacer()

            if viewModel.isLastQuestion {
                CRTButton(
                    title: "SUBMIT",
                    icon: "checkmark.circle.fill",
                    color: CRT.greenAccent,
                    isLoading: viewModel.isSubmitting
                ) {
                    Task { await viewModel.submitQuiz() }
                }
                .disabled(!viewModel.currentAnswerSelected)
            } else {
                CRTButton(title: "NEXT", icon: "chevron.right") {
                    withAnimation { viewModel.nextQuestion() }
                }
                .disabled(!viewModel.currentAnswerSelected)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(CRT.bgPanel)
        .overlay(alignment: .top) {
            CRTSeparator()
        }
    }
}
