import SwiftUI

/// Records — full file/folder browser with create, open, delete
struct RecordsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(FileService.self) private var fileService
    @State private var searchText = ""
    @State private var selectedFolder: String? = nil
    @State private var showCreateFile = false
    @State private var showCreateFolder = false
    @State private var selectedFile: FileRecord? = nil
    @State private var appeared = false

    var body: some View {
        ZStack {
            BlobBackground()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: - Stat Row (stat-card style)
                HStack(spacing: 12) {
                    StatBadge(
                        value: "\(fileService.fileCount)",
                        label: "Files",
                        color: Molten.Accent.warm
                    )
                    StatBadge(
                        value: "\(fileService.noteCount)",
                        label: "Notes",
                        color: Molten.Accent.primary
                    )
                    StatBadge(
                        value: "\(fileService.folders.count)",
                        label: "Folders",
                        color: Molten.Text.secondary
                    )
                }
                .padding(.bottom, 18)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.easeOut(duration: 0.5), value: appeared)

                // MARK: - Search Bar (glass-search style)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(Molten.Text.tertiary)
                    TextField("Search files...", text: $searchText)
                        .font(.moltenBody(14))
                        .foregroundStyle(Molten.Text.primary)
                        .tint(Molten.Accent.primary)
                }
                .glassSearch()
                .padding(.bottom, 14)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.easeOut(duration: 0.5).delay(0.05), value: appeared)

                // MARK: - Folder Pills (avatar-circle / glass-pill row)
                if !fileService.folders.isEmpty {
                    Text("FOLDERS")
                        .font(.moltenSmall())
                        .tracking(1.5)
                        .foregroundStyle(Molten.Text.tertiary)
                        .padding(.bottom, 10)
                        .padding(.leading, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FolderChip(name: "All", isSelected: selectedFolder == nil) {
                                selectedFolder = nil
                            }
                            ForEach(fileService.folders, id: \.self) { folder in
                                FolderChip(name: folder, isSelected: selectedFolder == folder) {
                                    selectedFolder = selectedFolder == folder ? nil : folder
                                }
                            }
                        }
                    }
                    .padding(.bottom, 18)
                }

                // MARK: - Action Buttons (settings-row style)
                HStack(spacing: 10) {
                    ActionButton(icon: "doc.badge.plus", label: "New File") {
                        showCreateFile = true
                    }
                    ActionButton(icon: "folder.badge.plus", label: "New Folder") {
                        showCreateFolder = true
                    }
                }
                .padding(.bottom, 18)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                // MARK: - File List (note-card style)
                if fileService.isLoading {
                    ProgressView()
                        .tint(Molten.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if filteredFiles.isEmpty {
                    EmptyState(
                        icon: "folder",
                        message: searchText.isEmpty
                            ? "No files yet. Tap New File to get started."
                            : "No files match \"\(searchText)\""
                    )
                } else {
                    Text("FILES")
                        .font(.moltenSmall())
                        .tracking(1.5)
                        .foregroundStyle(Molten.Text.tertiary)
                        .padding(.bottom, 10)
                        .padding(.leading, 4)

                    ForEach(Array(filteredFiles.enumerated()), id: \.element.id) { index, file in
                        FileRow(file: file) {
                            selectedFile = file
                        } onDelete: {
                            Task {
                                _ = await fileService.deleteFile(id: file.id, token: auth.accessToken)
                            }
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(
                            .easeOut(duration: 0.45).delay(0.12 + Double(index) * 0.04),
                            value: appeared
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        } // ZStack
        .navigationTitle("Records")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            appeared = true
            guard auth.isLoggedIn else { return }
            Task { await fileService.fetchFiles(token: auth.accessToken) }
        }
        .sheet(isPresented: $showCreateFile) {
            CreateFileSheet { filename, content, folder in
                Task {
                    _ = await fileService.createFile(
                        filename: filename, content: content,
                        folder: folder, token: auth.accessToken
                    )
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderSheet { folderName, filename in
                Task {
                    _ = await fileService.createFile(
                        filename: filename, content: "",
                        folder: folderName, token: auth.accessToken
                    )
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        // Full-screen editor (replaces the sheet below).
        // FileDetailSheet is kept intact further down in case we need to revert.
        .fullScreenCover(item: $selectedFile) { file in
            FileEditorView(file: file)
        }
        // MARK: - Archived: FileDetailSheet (read-only sheet — kept for reference)
        // To revert: remove the .fullScreenCover block above and uncomment this.
        // .sheet(item: $selectedFile) { file in
        //     FileDetailSheet(file: file)
        //         .presentationDetents([.large])
        //         .presentationDragIndicator(.visible)
        //         .presentationBackground(.ultraThinMaterial)
        // }
    }

    private var filteredFiles: [FileRecord] {
        var result = fileService.files
        if let folder = selectedFolder {
            result = result.filter { $0.folder == folder }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.filename.lowercased().contains(query) ||
                $0.folder.lowercased().contains(query)
            }
        }
        return result
    }
}

// MARK: - Stat Badge (stat-card from HTML)

private struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.moltenStat(28))
                .foregroundStyle(color)
            Text(label)
                .font(.moltenSmall(10))
                .tracking(1)
                .foregroundStyle(Molten.Text.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: Molten.Radius.xl, padding: 16)
    }
}

// MARK: - Folder Chip (avatar-circle style)

private struct FolderChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .font(.system(size: 12))
                Text(name)
                    .font(.moltenSmall())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule().fill(
                            isSelected
                                ? Molten.Accent.primary.opacity(0.12)
                                : Color.white.opacity(0.058)
                        )
                    )
            )
            .overlay(
                Capsule().stroke(
                    isSelected
                        ? Molten.Accent.primary.opacity(0.3)
                        : Color.white.opacity(0.115),
                    lineWidth: 1
                )
            )
            .foregroundStyle(isSelected ? Molten.Accent.primary : Molten.Text.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Button (settings-row inspired)

private struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Molten.Accent.primary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Molten.Accent.primary.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Molten.Accent.primary.opacity(0.2), lineWidth: 1)
                            )
                    )
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Molten.Text.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCardSmall()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - File Row (note-card style with swipe delete)

private struct FileRow: View {
    let file: FileRecord
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Extension icon (c1-upload-icon style)
                Image(systemName: iconForExtension(file.extension))
                    .font(.system(size: 16))
                    .foregroundStyle(colorForExtension(file.extension))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorForExtension(file.extension).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorForExtension(file.extension).opacity(0.2), lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.filename)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Molten.Text.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(formattedDate(file.updatedAt))
                            .font(.system(size: 11))
                            .foregroundStyle(Molten.Text.tertiary)

                        if !file.folder.isEmpty {
                            Text(file.folder)
                                .glassPill()
                        }

                        Text(".\(file.extension)")
                            .glassPill(accent: file.extension == "py")
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Molten.Text.tertiary)
            }
            .glassCard(radius: Molten.Radius.xl, padding: 14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Empty State

private struct EmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(Molten.Text.tertiary)
            Text(message)
                .font(.moltenBody(14))
                .foregroundStyle(Molten.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Create File Sheet

private struct CreateFileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var filename = ""
    @State private var content = ""
    @State private var folder = ""

    let onCreate: (String, String, String) -> Void

    private var isValid: Bool {
        let name = filename.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return false }
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        return ["py", "md", "swift"].contains(ext)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New File")
                .font(.moltenTitle(22))
                .foregroundStyle(Molten.Text.primary)
                .padding(.top, 8)

            // Filename
            VStack(alignment: .leading, spacing: 6) {
                Text("FILENAME")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("example.py", text: $filename)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            // Folder (optional)
            VStack(alignment: .leading, spacing: 6) {
                Text("FOLDER (OPTIONAL)")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("backend", text: $folder)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text("CONTENT")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextEditor(text: $content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .glassCardSmall()
            }

            HStack(spacing: 10) {
                Text(".py  .md  .swift")
                    .font(.moltenSmall())
                    .foregroundStyle(Molten.Text.tertiary)
                Spacer()
            }

            // Create button (c1-confirm-btn style)
            Button {
                onCreate(filename, content, folder)
                dismiss()
            } label: {
                Text("Create File")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Molten.Base._950)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Molten.Accent.primary, Molten.Accent.warm],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: Molten.Shadow.fab, radius: 8, x: 0, y: 4)
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.4)
        }
        .padding(24)
    }
}

// MARK: - Create Folder Sheet

private struct CreateFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var folderName = ""
    @State private var seedFilename = ""

    let onCreate: (String, String) -> Void

    private var isValid: Bool {
        let folder = folderName.trimmingCharacters(in: .whitespaces)
        let file = seedFilename.trimmingCharacters(in: .whitespaces)
        guard !folder.isEmpty, !file.isEmpty else { return false }
        let ext = file.components(separatedBy: ".").last?.lowercased() ?? ""
        return ["py", "md", "swift"].contains(ext)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Folder")
                .font(.moltenTitle(22))
                .foregroundStyle(Molten.Text.primary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("FOLDER NAME")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("my-project", text: $folderName)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("FIRST FILE")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("main.py", text: $seedFilename)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            Text("A folder is created by adding a file to it.")
                .font(.moltenSmall())
                .foregroundStyle(Molten.Text.tertiary)
                .padding(.top, 4)

            Spacer()

            Button {
                onCreate(folderName, seedFilename)
                dismiss()
            } label: {
                Text("Create Folder")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Molten.Base._950)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Molten.Accent.primary, Molten.Accent.warm],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .shadow(color: Molten.Shadow.fab, radius: 8, x: 0, y: 4)
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.4)
        }
        .padding(24)
    }
}

// MARK: - File Detail Sheet

private struct FileDetailSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(FileService.self) private var fileService
    let file: FileRecord
    @State private var detail: FileDetail?
    @State private var isLoading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header (c1-upload-top style)
                HStack(spacing: 12) {
                    Image(systemName: iconForExtension(file.extension))
                        .font(.system(size: 18))
                        .foregroundStyle(Molten.Accent.primary)
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Molten.Accent.primary.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Molten.Accent.primary.opacity(0.22), lineWidth: 1)
                                )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Molten.Text.primary)
                        Text(formattedDate(file.updatedAt))
                            .font(.moltenSmall())
                            .foregroundStyle(Molten.Text.tertiary)
                    }
                    Spacer()
                }
                .padding(.bottom, 20)

                // Divider (c1-divider)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.bottom, 16)

                // Info rows (detail-row style)
                InfoRow(label: "Extension", value: ".\(file.extension)")
                if !file.folder.isEmpty {
                    InfoRow(label: "Folder", value: file.folder)
                }
                InfoRow(label: "Size", value: formatBytes(file.sizeBytes))
                InfoRow(label: "Created", value: formattedDateFull(file.createdAt))

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.vertical, 16)

                // Content
                Text("CONTENT")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                    .padding(.bottom, 10)

                if isLoading {
                    ProgressView()
                        .tint(Molten.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                } else if let detail, !detail.content.isEmpty {
                    Text(detail.content)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Molten.Text.secondary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCardSmall()
                } else {
                    Text("Empty file")
                        .font(.moltenBody(13))
                        .foregroundStyle(Molten.Text.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }
            .padding(24)
            .padding(.bottom, 40)
        }
        .task {
            detail = await fileService.getFile(id: file.id, token: auth.accessToken)
            isLoading = false
        }
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext {
        case "swift": return "swift"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "md": return "doc.text"
        default: return "doc"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private func formattedDateFull(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return f.string(from: date)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024.0)
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Molten.Text.tertiary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Molten.Text.primary)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }
}
