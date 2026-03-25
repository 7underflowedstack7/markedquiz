import SwiftUI
import UIKit

// MARK: - FileEditorView
// Full-screen file editor. Defaults to render mode (formatted markdown / syntax-highlighted code).
// Toggle switches to edit mode with a live text editor.
// For .md files, a formatting toolbar is attached to the keyboard.

struct FileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(FileService.self) private var fileService

    let file: FileRecord

    // MARK: State

    @State private var detail: FileDetail?
    @State private var isLoadingContent = true
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var originalContent = ""
    @State private var isSaving = false
    @State private var showSavedConfirmation = false
    @State private var showDiscardAlert = false
    @State private var isRenamingFilename = false
    @State private var editedFilename = ""
    @State private var saveError: String?
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var textViewStore = TextViewStore()

    // MARK: - Computed

    private var hasUnsavedChanges: Bool {
        editedContent != originalContent || (isRenamingFilename && editedFilename != file.filename)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Molten.BG.deep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                editorHeader
                Divider()
                    .overlay(Color.white.opacity(0.08))

                if isLoadingContent {
                    loadingState
                } else {
                    editorBody
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .task {
            await loadContent()
        }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved modifications that will be lost.")
        }
        .alert("Delete \(file.filename)?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await deleteFile() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file will be permanently deleted. This cannot be undone.")
        }
        .overlay(alignment: .bottom) {
            if showSavedConfirmation {
                SavedToast()
                    .padding(.bottom, 48)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showSavedConfirmation)
        .sensoryFeedback(.success, trigger: showSavedConfirmation)
    }

    // MARK: - Header

    private var editorHeader: some View {
        HStack(spacing: 10) {
            // Close / back
            Button {
                handleDismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Molten.Text.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Molten.Glass.bg)
                            .overlay(Circle().stroke(Molten.Glass.border, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            // File icon
            Image(systemName: iconForExtension(file.extension))
                .font(.system(size: 14))
                .foregroundStyle(colorForExtension(file.extension))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorForExtension(file.extension).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colorForExtension(file.extension).opacity(0.22), lineWidth: 1)
                        )
                )

            // Filename + folder
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isRenamingFilename {
                        TextField("Filename", text: $editedFilename)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Molten.Text.primary)
                            .tint(Molten.Accent.primary)
                            .onSubmit { isRenamingFilename = false }
                            .submitLabel(.done)
                    } else {
                        Text(file.filename)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Molten.Text.primary)
                            .lineLimit(1)
                    }

                    if hasUnsavedChanges {
                        Circle()
                            .fill(Molten.Accent.warm)
                            .frame(width: 6, height: 6)
                    }
                }

                HStack(spacing: 6) {
                    Text(".\(file.extension)")
                        .glassPill(accent: file.extension == "py")

                    if !file.folder.isEmpty {
                        Text(file.folder)
                            .glassPill()
                    }
                }
            }

            Spacer()

            // Render / Edit toggle
            Button {
                toggleEditMode()
            } label: {
                Image(systemName: isEditing ? "eye" : "pencil")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isEditing ? Molten.Text.primary : Molten.Accent.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isEditing ? Molten.Accent.primary.opacity(0.15) : Molten.Glass.bg)
                            .overlay(
                                Circle().stroke(
                                    isEditing ? Molten.Accent.primary.opacity(0.3) : Molten.Glass.border,
                                    lineWidth: 1
                                )
                            )
                    )
            }
            .buttonStyle(.plain)

            // Save button (always visible)
            Button {
                Task { await saveFile() }
            } label: {
                HStack(spacing: 5) {
                    if isSaving {
                        ProgressView()
                            .tint(Molten.Base._950)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text("Save")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(hasUnsavedChanges ? Molten.Base._950 : Molten.Text.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        hasUnsavedChanges
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Molten.Accent.primary, Molten.Accent.warm],
                                startPoint: .leading,
                                endPoint: .trailing
                              ))
                            : AnyShapeStyle(Molten.Glass.bg)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        hasUnsavedChanges ? Color.clear : Molten.Glass.border,
                        lineWidth: 1
                    )
                )
                .shadow(color: hasUnsavedChanges ? Molten.Shadow.fab : .clear, radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(isSaving || !hasUnsavedChanges)

            // Overflow menu
            Menu {
                Button {
                    editedFilename = file.filename
                    isRenamingFilename = true
                } label: {
                    Label("Rename File", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete File", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(Molten.Text.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Molten.Accent.primary)
                .scaleEffect(1.2)
            Text("Loading file…")
                .font(.moltenBody(13))
                .foregroundStyle(Molten.Text.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Editor Body

    @ViewBuilder
    private var editorBody: some View {
        if isEditing {
            editingPane
        } else {
            readingPane
        }
    }

    // MARK: - Reading Pane (render mode)

    private var readingPane: some View {
        ScrollView(showsIndicators: false) {
            if !editedContent.isEmpty {
                if file.extension == "md" {
                    MarkdownRenderedView(content: editedContent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                        .padding(.bottom, 60)
                } else {
                    LineNumberedCode(
                        content: editedContent,
                        fileExtension: file.extension
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .padding(.bottom, 60)
                }
            } else if !isLoadingContent {
                VStack(spacing: 14) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundStyle(Molten.Text.tertiary)
                    Text("Empty file — tap Edit to add content.")
                        .font(.moltenBody(13))
                        .foregroundStyle(Molten.Text.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            }
        }
    }

    // MARK: - Editing Pane

    private var editingPane: some View {
        RichTextEditor(text: $editedContent, store: textViewStore, fileExtension: file.extension)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadContent() async {
        isLoadingContent = true
        let loaded = await fileService.getFile(id: file.id, token: auth.accessToken)
        detail = loaded
        let content = loaded?.content ?? ""
        originalContent = content
        editedContent = content
        isLoadingContent = false
    }

    private func toggleEditMode() {
        if !isEditing {
            // Entering edit mode — sync content
            editedContent = editedContent.isEmpty ? (detail?.content ?? "") : editedContent
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing.toggle()
        }
    }

    private func saveFile() async {
        isSaving = true
        saveError = nil

        let newFilename = (isRenamingFilename && !editedFilename.trimmingCharacters(in: .whitespaces).isEmpty)
            ? editedFilename.trimmingCharacters(in: .whitespaces)
            : nil

        let updated = await fileService.updateFile(
            id: file.id,
            content: editedContent,
            filename: newFilename,
            token: auth.accessToken
        )
        isSaving = false

        if let updated {
            detail = updated
            originalContent = updated.content
            editedContent = updated.content
            isRenamingFilename = false
            withAnimation { showSavedConfirmation = true }
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation { showSavedConfirmation = false }
            }
        } else {
            saveError = fileService.error ?? "Save failed"
        }
    }

    private func deleteFile() async {
        isDeleting = true
        let success = await fileService.deleteFile(id: file.id, token: auth.accessToken)
        isDeleting = false
        if success {
            dismiss()
        }
    }

    private func handleDismiss() {
        if hasUnsavedChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    // MARK: - Helpers

    private func iconForExtension(_ ext: String) -> String {
        switch ext {
        case "swift": return "swift"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "md": return "doc.text"
        default: return "doc"
        }
    }

    private func colorForExtension(_ ext: String) -> Color {
        switch ext {
        case "swift": return Color(hex: 0xF05138)
        case "py": return Molten.Accent.warm
        case "md": return Molten.Accent.primary
        default: return Molten.Text.secondary
        }
    }
}

// MARK: - TextViewStore
// Shared reference so toolbar buttons can interact with the UITextView.

@MainActor @Observable
final class TextViewStore {
    weak var textView: UITextView?

    func insertAtCursor(_ text: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard let textRange = Range(range, in: tv.text ?? "") else {
            tv.insertText(text)
            return
        }
        var current = tv.text ?? ""
        current.replaceSubrange(textRange, with: text)
        tv.text = current
        let newPos = range.location + text.utf16.count
        tv.selectedRange = NSRange(location: newPos, length: 0)
        // Notify delegate so binding syncs
        tv.delegate?.textViewDidChange?(tv)
    }

    func wrapSelection(prefix: String, suffix: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let current = tv.text ?? ""

        if range.length > 0, let textRange = Range(range, in: current) {
            // Wrap selected text
            let selected = String(current[textRange])
            let replacement = prefix + selected + suffix
            var updated = current
            updated.replaceSubrange(textRange, with: replacement)
            tv.text = updated
            // Select the inner text (between prefix and suffix)
            let innerStart = range.location + prefix.utf16.count
            tv.selectedRange = NSRange(location: innerStart, length: selected.utf16.count)
        } else {
            // No selection — insert prefix+suffix, cursor between them
            let insertion = prefix + suffix
            guard let textRange = Range(range, in: current) else {
                tv.insertText(insertion)
                return
            }
            var updated = current
            updated.replaceSubrange(textRange, with: insertion)
            tv.text = updated
            let cursorPos = range.location + prefix.utf16.count
            tv.selectedRange = NSRange(location: cursorPos, length: 0)
        }
        tv.delegate?.textViewDidChange?(tv)
    }
}

// MARK: - RichTextEditor (UIViewRepresentable)
// Generic text editor that attaches a language-specific toolbar to the keyboard
// and applies live syntax highlighting for Swift/Python files.

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    let store: TextViewStore
    let fileExtension: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textColor = UIColor(Molten.Text.secondary)
        tv.backgroundColor = .clear
        tv.tintColor = UIColor(Molten.Accent.primary)
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.keyboardAppearance = .dark
        tv.delegate = context.coordinator
        tv.text = text

        // Pick toolbar based on file type
        let toolbarContent: AnyView = switch fileExtension {
        case "md": AnyView(MarkdownToolbarView(store: store))
        case "swift": AnyView(SwiftToolbarView(store: store))
        case "py": AnyView(PythonToolbarView(store: store))
        default: AnyView(SwiftToolbarView(store: store))
        }

        let host = UIHostingController(rootView: toolbarContent)
        host.view.frame = CGRect(x: 0, y: 0, width: 0, height: 44)
        host.view.autoresizingMask = [.flexibleWidth]
        host.view.backgroundColor = UIColor(Molten.BG.deep)
        tv.inputAccessoryView = host.view

        store.textView = tv

        // Apply initial highlighting
        SyntaxHighlighter.highlight(tv, fileExtension: fileExtension)

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            SyntaxHighlighter.highlight(uiView, fileExtension: fileExtension)
            let maxLen = (text as NSString).length
            if selectedRange.location <= maxLen {
                uiView.selectedRange = selectedRange
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            SyntaxHighlighter.highlight(textView, fileExtension: parent.fileExtension)
        }
    }
}

// MARK: - SyntaxHighlighter
// Applies live syntax coloring to a UITextView's textStorage using regex.
// Order: reset all → keywords → strings (override keywords inside) → comments (override all inside).

enum SyntaxHighlighter {

    // MARK: Colors

    private static let defaultColor = UIColor(Molten.Text.secondary)
    private static let keywordColor = UIColor(Molten.Accent.primary)
    private static let stringColor  = UIColor(Molten.Accent.warm)
    private static let commentColor = UIColor(Molten.Text.tertiary)
    private static let defaultFont  = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private static let keywordFont  = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)

    // MARK: Keyword Sets

    private static let swiftKeywords: Set<String> = [
        "func", "var", "let", "struct", "class", "import", "return", "if", "else",
        "guard", "for", "while", "switch", "case", "enum", "protocol", "private",
        "public", "internal", "static", "self", "true", "false", "nil", "in",
        "where", "throw", "throws", "try", "catch", "async", "await", "final",
        "override", "init", "deinit", "extension", "typealias", "lazy", "mutating",
        "some", "any", "open", "fileprivate", "default", "break", "continue",
        "defer", "do", "repeat", "is", "as", "super", "Self", "Type",
        "@State", "@Binding", "@Observable", "@Environment", "@MainActor",
        "@ViewBuilder", "@Published", "@ObservedObject", "@StateObject"
    ]

    private static let pythonKeywords: Set<String> = [
        "def", "class", "import", "from", "return", "if", "else", "elif", "for",
        "while", "try", "except", "with", "as", "in", "not", "and", "or", "True",
        "False", "None", "self", "print", "raise", "pass", "break", "continue",
        "lambda", "yield", "async", "await", "global", "nonlocal", "del", "is",
        "finally", "assert", "elif"
    ]

    // MARK: Compiled Patterns

    private static let swiftKeywordPattern: NSRegularExpression? = {
        let words = swiftKeywords.map { NSRegularExpression.escapedPattern(for: $0) }
        let atWords = words.filter { $0.hasPrefix("@") }.joined(separator: "|")
        let plainWords = words.filter { !$0.hasPrefix("@") }.joined(separator: "|")
        var pattern = "\\b(\(plainWords))\\b"
        if !atWords.isEmpty {
            pattern = "(\(atWords))|\\b(\(plainWords))\\b"
        }
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    private static let pythonKeywordPattern: NSRegularExpression? = {
        let words = pythonKeywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return try? NSRegularExpression(pattern: "\\b(\(words))\\b", options: [])
    }()

    // Strings: double-quoted and single-quoted, with escape support
    private static let doubleStringPattern = try? NSRegularExpression(
        pattern: "\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", options: []
    )
    private static let singleStringPattern = try? NSRegularExpression(
        pattern: "'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", options: []
    )
    // Triple-quoted strings (Python)
    private static let tripleDoubleStringPattern = try? NSRegularExpression(
        pattern: "\"\"\"[\\s\\S]*?\"\"\"", options: []
    )
    private static let tripleSingleStringPattern = try? NSRegularExpression(
        pattern: "'''[\\s\\S]*?'''", options: []
    )

    // Comments
    private static let swiftCommentPattern = try? NSRegularExpression(
        pattern: "//.*$", options: [.anchorsMatchLines]
    )
    private static let pythonCommentPattern = try? NSRegularExpression(
        pattern: "#.*$", options: [.anchorsMatchLines]
    )

    // MARK: - Apply

    static func highlight(_ textView: UITextView, fileExtension: String) {
        guard fileExtension == "swift" || fileExtension == "py" else { return }

        let storage = textView.textStorage
        let text = storage.string
        guard !text.isEmpty else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        let selectedRange = textView.selectedRange

        storage.beginEditing()

        // 1. Reset everything to default
        storage.setAttributes([
            .foregroundColor: defaultColor,
            .font: defaultFont
        ], range: fullRange)

        // 2. Keywords
        let keywordRegex = fileExtension == "swift" ? swiftKeywordPattern : pythonKeywordPattern
        keywordRegex?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            storage.addAttributes([
                .foregroundColor: keywordColor,
                .font: keywordFont
            ], range: range)
        }

        // 3. Strings (override keywords inside strings)
        if fileExtension == "py" {
            // Triple-quoted first (greedy, before single/double)
            for pattern in [tripleDoubleStringPattern, tripleSingleStringPattern] {
                pattern?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                    guard let range = match?.range else { return }
                    storage.addAttributes([
                        .foregroundColor: stringColor,
                        .font: defaultFont
                    ], range: range)
                }
            }
        }
        for pattern in [doubleStringPattern, singleStringPattern] {
            // Skip single-quote strings for Swift
            if fileExtension == "swift" && pattern === singleStringPattern { continue }
            pattern?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let range = match?.range else { return }
                storage.addAttributes([
                    .foregroundColor: stringColor,
                    .font: defaultFont
                ], range: range)
            }
        }

        // 4. Comments (highest priority — override everything)
        let commentRegex = fileExtension == "swift" ? swiftCommentPattern : pythonCommentPattern
        commentRegex?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            storage.addAttributes([
                .foregroundColor: commentColor,
                .font: defaultFont
            ], range: range)
        }

        storage.endEditing()

        // Restore cursor
        textView.selectedRange = selectedRange
    }
}

// MARK: - MarkdownToolbarView (keyboard accessory)

struct MarkdownToolbarView: View {
    let store: TextViewStore

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ToolbarBtn(label: "H1") { store.insertAtCursor("# ") }
                    ToolbarBtn(label: "H2") { store.insertAtCursor("## ") }
                    ToolbarBtn(label: "H3") { store.insertAtCursor("### ") }

                    ToolbarDivider()

                    ToolbarBtn(systemImage: "bold") { store.wrapSelection(prefix: "**", suffix: "**") }
                    ToolbarBtn(systemImage: "italic") { store.wrapSelection(prefix: "*", suffix: "*") }

                    ToolbarDivider()

                    ToolbarBtn(systemImage: "list.bullet") { store.insertAtCursor("- ") }
                    ToolbarBtn(systemImage: "list.number") { store.insertAtCursor("1. ") }

                    ToolbarDivider()

                    ToolbarBtn(systemImage: "chevron.left.forwardslash.chevron.right") {
                        store.wrapSelection(prefix: "`", suffix: "`")
                    }
                    ToolbarBtn(systemImage: "link") {
                        store.wrapSelection(prefix: "[", suffix: "](url)")
                    }
                }
                .padding(.horizontal, 12)
            }

            // Dismiss keyboard button
            Button {
                store.textView?.resignFirstResponder()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 15))
                    .foregroundStyle(Molten.Text.secondary)
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .frame(height: 44)
        .background(Color(UIColor(Molten.BG.deep)))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
    }
}

// MARK: - SwiftToolbarView (keyboard accessory for .swift files)

struct SwiftToolbarView: View {
    let store: TextViewStore

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Bracket pairs (wrap selection or insert pair with cursor inside)
                    ToolbarBtn(label: "( )") { store.wrapSelection(prefix: "(", suffix: ")") }
                    ToolbarBtn(label: "{ }") { store.wrapSelection(prefix: "{", suffix: "}") }
                    ToolbarBtn(label: "[ ]") { store.wrapSelection(prefix: "[", suffix: "]") }
                    ToolbarBtn(label: "< >") { store.wrapSelection(prefix: "<", suffix: ">") }

                    ToolbarDivider()

                    // Strings
                    ToolbarBtn(label: "\" \"") { store.wrapSelection(prefix: "\"", suffix: "\"") }

                    ToolbarDivider()

                    // Operators & punctuation
                    ToolbarBtn(label: "->") { store.insertAtCursor("-> ") }
                    ToolbarBtn(label: ".") { store.insertAtCursor(".") }
                    ToolbarBtn(label: ":") { store.insertAtCursor(": ") }
                    ToolbarBtn(label: "=") { store.insertAtCursor(" = ") }
                    ToolbarBtn(label: "?") { store.insertAtCursor("?") }
                    ToolbarBtn(label: "!") { store.insertAtCursor("!") }

                    ToolbarDivider()

                    ToolbarBtn(label: "//") { store.insertAtCursor("// ") }
                    ToolbarBtn(label: "_") { store.insertAtCursor("_") }
                    ToolbarBtn(label: "⇥") { store.insertAtCursor("    ") }
                }
                .padding(.horizontal, 12)
            }

            Button {
                store.textView?.resignFirstResponder()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 15))
                    .foregroundStyle(Molten.Text.secondary)
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .frame(height: 44)
        .background(Color(UIColor(Molten.BG.deep)))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
    }
}

// MARK: - PythonToolbarView (keyboard accessory for .py files)

struct PythonToolbarView: View {
    let store: TextViewStore

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Bracket pairs
                    ToolbarBtn(label: "( )") { store.wrapSelection(prefix: "(", suffix: ")") }
                    ToolbarBtn(label: "[ ]") { store.wrapSelection(prefix: "[", suffix: "]") }
                    ToolbarBtn(label: "{ }") { store.wrapSelection(prefix: "{", suffix: "}") }

                    ToolbarDivider()

                    // Strings
                    ToolbarBtn(label: "\" \"") { store.wrapSelection(prefix: "\"", suffix: "\"") }
                    ToolbarBtn(label: "' '") { store.wrapSelection(prefix: "'", suffix: "'") }

                    ToolbarDivider()

                    // Operators & punctuation
                    ToolbarBtn(label: ":") { store.insertAtCursor(": ") }
                    ToolbarBtn(label: "=") { store.insertAtCursor(" = ") }
                    ToolbarBtn(label: ".") { store.insertAtCursor(".") }
                    ToolbarBtn(label: "->") { store.insertAtCursor(" -> ") }
                    ToolbarBtn(label: "**") { store.insertAtCursor("**") }
                    ToolbarBtn(label: "_") { store.insertAtCursor("_") }

                    ToolbarDivider()

                    ToolbarBtn(label: "#") { store.insertAtCursor("# ") }
                    ToolbarBtn(label: "⇥") { store.insertAtCursor("    ") }
                }
                .padding(.horizontal, 12)
            }

            Button {
                store.textView?.resignFirstResponder()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 15))
                    .foregroundStyle(Molten.Text.secondary)
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .frame(height: 44)
        .background(Color(UIColor(Molten.BG.deep)))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
        }
    }
}

// MARK: - Toolbar Components

private struct ToolbarBtn: View {
    var label: String?
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let label {
                    Text(label)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundStyle(Molten.Text.secondary)
            .frame(width: 36, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Molten.Card.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Molten.Card.border, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
    }
}

// MARK: - Line Numbered Code View

/// Renders file content with a line-number gutter and basic syntax highlighting.
private struct LineNumberedCode: View {
    let content: String
    let fileExtension: String

    private var lines: [String] {
        content.components(separatedBy: "\n")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Gutter
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Molten.Text.tertiary)
                        .frame(minWidth: 36, alignment: .trailing)
                        .padding(.vertical, 1)
                }
            }
            .padding(.trailing, 12)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)
                    .padding(.trailing, -1)
            }

            // Code
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(highlightedLine(line))
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.leading, 16)
        }
    }

    // MARK: - Syntax Highlighting

    private func highlightedLine(_ line: String) -> AttributedString {
        switch fileExtension {
        case "swift": return highlightSwift(line)
        case "py": return highlightPython(line)
        case "md": return highlightMarkdown(line)
        default: return plain(line)
        }
    }

    private func plain(_ line: String) -> AttributedString {
        var a = AttributedString(line)
        a.foregroundColor = UIColor(Molten.Text.secondary)
        return a
    }

    // MARK: Swift

    private static let swiftKeywords: Set<String> = [
        "func", "var", "let", "struct", "class", "import", "return", "if", "else",
        "guard", "for", "while", "switch", "case", "enum", "protocol", "private",
        "public", "internal", "static", "self", "true", "false", "nil", "in",
        "where", "throw", "throws", "try", "catch", "async", "await", "final",
        "override", "init", "deinit", "extension", "typealias", "lazy", "mutating",
        "some", "any", "open", "fileprivate"
    ]

    private func highlightSwift(_ line: String) -> AttributedString {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
            var a = AttributedString(line)
            a.foregroundColor = UIColor(Molten.Text.tertiary)
            return a
        }
        return tokenize(
            line: line,
            keywords: Self.swiftKeywords,
            stringDelimiters: ["\""],
            lineCommentPrefix: "//"
        )
    }

    // MARK: Python

    private static let pythonKeywords: Set<String> = [
        "def", "class", "import", "from", "return", "if", "else", "elif", "for",
        "while", "try", "except", "with", "as", "in", "not", "and", "or", "True",
        "False", "None", "self", "print", "raise", "pass", "break", "continue",
        "lambda", "yield", "async", "await", "global", "nonlocal", "del", "is"
    ]

    private func highlightPython(_ line: String) -> AttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            var a = AttributedString(line)
            a.foregroundColor = UIColor(Molten.Text.tertiary)
            return a
        }
        return tokenize(
            line: line,
            keywords: Self.pythonKeywords,
            stringDelimiters: ["\"", "'"],
            lineCommentPrefix: "#"
        )
    }

    // MARK: Markdown

    private func highlightMarkdown(_ line: String) -> AttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#") {
            var a = AttributedString(line)
            a.foregroundColor = UIColor(Molten.Accent.primary)
            a.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            return a
        }

        if trimmed.contains("**") || trimmed.contains("](") {
            return highlightMarkdownInline(line)
        }

        var a = AttributedString(line)
        a.foregroundColor = UIColor(Molten.Text.secondary)
        return a
    }

    private func highlightMarkdownInline(_ line: String) -> AttributedString {
        var result = AttributedString()
        var remaining = line[line.startIndex...]

        while !remaining.isEmpty {
            if let boldStart = remaining.range(of: "**") {
                let before = String(remaining[remaining.startIndex..<boldStart.lowerBound])
                if !before.isEmpty {
                    var a = AttributedString(before)
                    a.foregroundColor = UIColor(Molten.Text.secondary)
                    result += a
                }
                let afterBold = remaining[boldStart.upperBound...]
                if let boldEnd = afterBold.range(of: "**") {
                    let boldContent = String(afterBold[afterBold.startIndex..<boldEnd.lowerBound])
                    var a = AttributedString("**\(boldContent)**")
                    a.foregroundColor = UIColor(Molten.Text.primary)
                    a.font = UIFont.boldSystemFont(ofSize: 13)
                    result += a
                    remaining = afterBold[boldEnd.upperBound...]
                } else {
                    var a = AttributedString(String(remaining))
                    a.foregroundColor = UIColor(Molten.Text.secondary)
                    result += a
                    break
                }
            } else if let linkLabelStart = remaining.range(of: "[") {
                let before = String(remaining[remaining.startIndex..<linkLabelStart.lowerBound])
                if !before.isEmpty {
                    var a = AttributedString(before)
                    a.foregroundColor = UIColor(Molten.Text.secondary)
                    result += a
                }
                let afterBracket = remaining[linkLabelStart.lowerBound...]
                if let linkEnd = afterBracket.range(of: ")"),
                   afterBracket.contains("](") {
                    let fullLink = String(afterBracket[afterBracket.startIndex...linkEnd.lowerBound])
                    var a = AttributedString(fullLink)
                    a.foregroundColor = UIColor(Molten.Accent.warm)
                    result += a
                    remaining = afterBracket[linkEnd.upperBound...]
                } else {
                    var a = AttributedString(String(remaining))
                    a.foregroundColor = UIColor(Molten.Text.secondary)
                    result += a
                    break
                }
            } else {
                var a = AttributedString(String(remaining))
                a.foregroundColor = UIColor(Molten.Text.secondary)
                result += a
                break
            }
        }
        return result
    }

    // MARK: - Generic Tokenizer

    private func tokenize(
        line: String,
        keywords: Set<String>,
        stringDelimiters: [Character],
        lineCommentPrefix: String
    ) -> AttributedString {
        var result = AttributedString()
        var i = line.startIndex

        while i < line.endIndex {
            let ch = line[i]

            if line[i...].hasPrefix(lineCommentPrefix) {
                let rest = String(line[i...])
                var a = AttributedString(rest)
                a.foregroundColor = UIColor(Molten.Text.tertiary)
                result += a
                break
            }

            if stringDelimiters.contains(ch) {
                let delimiter = ch
                var j = line.index(after: i)
                while j < line.endIndex {
                    if line[j] == delimiter && (j == line.startIndex || line[line.index(before: j)] != "\\") {
                        j = line.index(after: j)
                        break
                    }
                    j = line.index(after: j)
                }
                let token = String(line[i..<j])
                var a = AttributedString(token)
                a.foregroundColor = UIColor(Molten.Accent.warm)
                result += a
                i = j
                continue
            }

            if ch.isLetter || ch == "_" {
                var j = i
                while j < line.endIndex && (line[j].isLetter || line[j].isNumber || line[j] == "_") {
                    j = line.index(after: j)
                }
                let word = String(line[i..<j])
                var a = AttributedString(word)
                a.foregroundColor = keywords.contains(word)
                    ? UIColor(Molten.Accent.primary)
                    : UIColor(Molten.Text.secondary)
                result += a
                i = j
                continue
            }

            var a = AttributedString(String(ch))
            a.foregroundColor = UIColor(Molten.Text.secondary)
            result += a
            i = line.index(after: i)
        }

        return result
    }
}

// MARK: - Markdown Rendered View

private struct MarkdownRenderedView: View {
    let content: String

    private var blocks: [MarkdownBlock] {
        parseMarkdown(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            inlineText(text)
                .padding(.bottom, 12)
        case .codeBlock(let code, let lang):
            codeBlockView(code: code, language: lang)
                .padding(.bottom, 12)
        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\u{2022}")
                    .font(.system(size: 14))
                    .foregroundStyle(Molten.Accent.primary)
                inlineText(text)
            }
            .padding(.leading, 8)
            .padding(.bottom, 4)
        case .numberedItem(let num, let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(num).")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Molten.Accent.primary)
                    .frame(minWidth: 20, alignment: .trailing)
                inlineText(text)
            }
            .padding(.leading, 4)
            .padding(.bottom, 4)
        case .blockquote(let text):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Molten.Accent.primary.opacity(0.5))
                    .frame(width: 3)
                inlineText(text)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 8)
        case .horizontalRule:
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 12)
        case .empty:
            Spacer().frame(height: 8)
        }
    }

    private func headingView(level: Int, text: String) -> some View {
        let size: CGFloat = switch level {
        case 1: 26
        case 2: 22
        case 3: 18
        default: 16
        }
        let bottomPad: CGFloat = level <= 2 ? 14 : 10

        return VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Molten.Text.primary)
            if level <= 2 {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, bottomPad)
    }

    private func codeBlockView(code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Molten.Text.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Molten.Text.secondary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, language != nil ? 8 : 12)
        }
        .background(
            RoundedRectangle(cornerRadius: Molten.Radius.sm)
                .fill(Molten.Card.bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Molten.Radius.sm)
                .stroke(Molten.Card.border, lineWidth: 1)
        )
    }

    private func inlineText(_ text: String) -> some View {
        Text(parseInlineMarkdown(text))
            .font(.system(size: 14))
            .lineSpacing(4)
    }

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            if remaining.first == "`", let endIdx = remaining[remaining.index(after: remaining.startIndex)...].firstIndex(of: "`") {
                let codeContent = String(remaining[remaining.index(after: remaining.startIndex)..<endIdx])
                var a = AttributedString(codeContent)
                a.font = .system(size: 12, design: .monospaced)
                a.foregroundColor = UIColor(Molten.Accent.warm)
                result += a
                remaining = remaining[remaining.index(after: endIdx)...]
                continue
            }

            if remaining.hasPrefix("**"), let endRange = remaining[remaining.index(remaining.startIndex, offsetBy: 2)...].range(of: "**") {
                let boldContent = String(remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<endRange.lowerBound])
                var a = AttributedString(boldContent)
                a.font = .system(size: 14, weight: .bold)
                a.foregroundColor = UIColor(Molten.Text.primary)
                result += a
                remaining = remaining[endRange.upperBound...]
                continue
            }

            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                let afterStar = remaining.index(after: remaining.startIndex)
                if let endIdx = remaining[afterStar...].firstIndex(of: "*"), endIdx != afterStar {
                    let italicContent = String(remaining[afterStar..<endIdx])
                    var a = AttributedString(italicContent)
                    a.font = .system(size: 14).italic()
                    a.foregroundColor = UIColor(Molten.Text.secondary)
                    result += a
                    remaining = remaining[remaining.index(after: endIdx)...]
                    continue
                }
            }

            if remaining.hasPrefix("[") {
                let afterBracket = remaining[remaining.index(after: remaining.startIndex)...]
                if let closeBracket = afterBracket.firstIndex(of: "]") {
                    let label = String(afterBracket[afterBracket.startIndex..<closeBracket])
                    let afterClose = remaining[remaining.index(after: closeBracket)...]
                    if afterClose.hasPrefix("("), let closeParen = afterClose.firstIndex(of: ")") {
                        var a = AttributedString(label)
                        a.foregroundColor = UIColor(Molten.Accent.warm)
                        a.underlineStyle = .single
                        result += a
                        remaining = remaining[remaining.index(after: closeParen)...]
                        continue
                    }
                }
            }

            let ch = remaining.first!
            var a = AttributedString(String(ch))
            a.foregroundColor = UIColor(Molten.Text.secondary)
            result += a
            remaining = remaining[remaining.index(after: remaining.startIndex)...]
        }

        return result
    }
}

// MARK: - Markdown Block Types

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(code: String, language: String?)
    case bulletItem(text: String)
    case numberedItem(number: Int, text: String)
    case blockquote(text: String)
    case horizontalRule
    case empty
}

// MARK: - Markdown Parser

private func parseMarkdown(_ content: String) -> [MarkdownBlock] {
    let lines = content.components(separatedBy: "\n")
    var blocks: [MarkdownBlock] = []
    var i = 0

    while i < lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            blocks.append(.empty)
            i += 1
            continue
        }

        if trimmed.hasPrefix("```") {
            let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var codeLines: [String] = []
            i += 1
            while i < lines.count {
                if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    i += 1
                    break
                }
                codeLines.append(lines[i])
                i += 1
            }
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: lang.isEmpty ? nil : lang))
            continue
        }

        if trimmed.hasPrefix("#") {
            let hashes = trimmed.prefix(while: { $0 == "#" })
            let level = min(hashes.count, 6)
            let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            blocks.append(.heading(level: level, text: text))
            i += 1
            continue
        }

        if trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" || $0 == " " }),
           trimmed.filter({ $0 != " " }).count >= 3,
           Set(trimmed.filter({ $0 != " " })).count == 1 {
            blocks.append(.horizontalRule)
            i += 1
            continue
        }

        if trimmed.hasPrefix(">") {
            let text = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            blocks.append(.blockquote(text: text))
            i += 1
            continue
        }

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            let text = String(trimmed.dropFirst(2))
            blocks.append(.bulletItem(text: text))
            i += 1
            continue
        }

        if let dotIndex = trimmed.firstIndex(of: "."),
           let num = Int(trimmed[trimmed.startIndex..<dotIndex]),
           trimmed[trimmed.index(after: dotIndex)...].hasPrefix(" ") {
            let text = String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...])
            blocks.append(.numberedItem(number: num, text: text))
            i += 1
            continue
        }

        blocks.append(.paragraph(text: trimmed))
        i += 1
    }

    return blocks
}

// MARK: - Saved Toast

private struct SavedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Molten.Accent.primary)
            Text("Saved")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Molten.Text.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Molten.Card.bg))
        )
        .overlay(
            Capsule().stroke(Molten.Accent.primary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Molten.Shadow.fab, radius: 12, x: 0, y: 6)
    }
}

// MARK: - Previews

#Preview("Read mode — Swift") {
    let auth = AuthService()
    let fileService = FileService()
    FileEditorView(
        file: FileRecord(
            id: 1,
            filename: "ContentView.swift",
            extension: "swift",
            folder: "frontend",
            path: "frontend/ContentView.swift",
            sizeBytes: 512,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .environment(auth)
    .environment(fileService)
}

#Preview("Read mode — Markdown") {
    let auth = AuthService()
    let fileService = FileService()
    FileEditorView(
        file: FileRecord(
            id: 3,
            filename: "README.md",
            extension: "md",
            folder: "",
            path: "README.md",
            sizeBytes: 128,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
    .environment(auth)
    .environment(fileService)
}
