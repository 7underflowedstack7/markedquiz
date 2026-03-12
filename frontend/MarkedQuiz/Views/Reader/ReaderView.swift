import SwiftUI

struct ReaderView: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                CRT.bgDeep.ignoresSafeArea()

                if viewModel.isLoading {
                    CRTLoadingView(message: "Loading document")
                } else if viewModel.elements.isEmpty {
                    CRTEmptyView(
                        icon: "doc.text",
                        title: "EMPTY DOCUMENT",
                        message: "This document has no content."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(viewModel.elements.enumerated()), id: \.offset) { index, element in
                                MarkdownElementView(
                                    element: element,
                                    fontSize: viewModel.fontSize
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }

                ScanlinesOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(CRT.orangeDim)
                    }
                    .accessibilityLabel(String(localized: "Close reader"))
                }

                ToolbarItem(placement: .principal) {
                    Text(viewModel.document?.title ?? "")
                        .font(CRT.monoBold(14))
                        .foregroundStyle(CRT.orangeBright)
                        .lineLimit(1)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.decreaseFontSize()
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundStyle(CRT.orangeDim)
                        }
                        .accessibilityLabel(String(localized: "Decrease font size"))

                        Button {
                            viewModel.increaseFontSize()
                        } label: {
                            Image(systemName: "textformat.size.larger")
                                .foregroundStyle(CRT.orangeDim)
                        }
                        .accessibilityLabel(String(localized: "Increase font size"))
                    }
                }
            }
            .toolbarBackground(CRT.bgPanel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct MarkdownElementView: View {
    let element: MarkdownElement
    let fontSize: CGFloat

    var body: some View {
        switch element {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            richText(text)
                .font(CRT.monoText(fontSize))
                .foregroundStyle(CRT.orangeBright)
                .lineSpacing(4)
                .padding(.bottom, 8)
        case .codeBlock(_, let code):
            codeBlockView(code: code)
        case .bulletItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text(">")
                    .font(CRT.monoText(fontSize))
                    .foregroundStyle(CRT.cyanAccent)
                richText(text)
                    .font(CRT.monoText(fontSize))
                    .foregroundStyle(CRT.orangeBright)
            }
            .padding(.bottom, 4)
            .padding(.leading, 8)
        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(CRT.monoBold(fontSize))
                    .foregroundStyle(CRT.cyanAccent)
                    .frame(width: 24, alignment: .trailing)
                richText(text)
                    .font(CRT.monoText(fontSize))
                    .foregroundStyle(CRT.orangeBright)
            }
            .padding(.bottom, 4)
        case .horizontalRule:
            CRTSeparator()
                .padding(.vertical, 8)
        case .blank:
            Spacer()
                .frame(height: 8)
        }
    }

    @ViewBuilder
    private func headingView(level: Int, text: String) -> some View {
        let size: CGFloat = switch level {
        case 1: fontSize + 10
        case 2: fontSize + 6
        case 3: fontSize + 3
        default: fontSize + 1
        }

        VStack(alignment: .leading, spacing: 4) {
            Text(String(repeating: "#", count: level) + " " + text)
                .font(CRT.monoBold(size))
                .foregroundStyle(level == 1 ? CRT.amber : CRT.orangeGlow)
                .crtGlow(color: CRT.orangeBright, radius: level == 1 ? 6 : 3)

            if level <= 2 {
                Rectangle()
                    .fill(CRT.orangeFaint)
                    .frame(height: 1)
            }
        }
        .padding(.top, level == 1 ? 16 : 12)
        .padding(.bottom, 8)
    }

    private func codeBlockView(code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CODE")
                    .font(CRT.monoText(10))
                    .foregroundStyle(CRT.textDim)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.08))

            Text(code)
                .font(CRT.monoText(fontSize - 1))
                .foregroundStyle(CRT.greenAccent)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CRT.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(CRT.orangeFaint.opacity(0.5), lineWidth: 1)
        )
        .padding(.vertical, 6)
    }

    private func richText(_ text: String) -> Text {
        // Parse inline markdown: **bold**, *italic*, `code`
        var result = Text("")
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold
            if let boldRange = remaining.range(of: "**") {
                let before = remaining[remaining.startIndex..<boldRange.lowerBound]
                if !before.isEmpty {
                    result = result + Text(before)
                }
                let afterBold = remaining[boldRange.upperBound...]
                if let endBold = afterBold.range(of: "**") {
                    let boldText = afterBold[afterBold.startIndex..<endBold.lowerBound]
                    result = result + Text(boldText).bold().foregroundColor(CRT.amber)
                    remaining = afterBold[endBold.upperBound...]
                    continue
                }
            }

            // Inline code
            if let codeRange = remaining.range(of: "`") {
                let before = remaining[remaining.startIndex..<codeRange.lowerBound]
                if !before.isEmpty {
                    result = result + Text(before)
                }
                let afterCode = remaining[codeRange.upperBound...]
                if let endCode = afterCode.range(of: "`") {
                    let codeText = afterCode[afterCode.startIndex..<endCode.lowerBound]
                    result = result + Text(codeText).foregroundColor(CRT.greenAccent)
                    remaining = afterCode[endCode.upperBound...]
                    continue
                }
            }

            // Italic
            if let italicRange = remaining.range(of: "*") {
                let before = remaining[remaining.startIndex..<italicRange.lowerBound]
                if !before.isEmpty {
                    result = result + Text(before)
                }
                let afterItalic = remaining[italicRange.upperBound...]
                if let endItalic = afterItalic.range(of: "*") {
                    let italicText = afterItalic[afterItalic.startIndex..<endItalic.lowerBound]
                    result = result + Text(italicText).italic()
                    remaining = afterItalic[endItalic.upperBound...]
                    continue
                }
            }

            // No more formatting found — append rest
            result = result + Text(remaining)
            break
        }

        return result
    }
}
