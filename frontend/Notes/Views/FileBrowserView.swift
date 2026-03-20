import SwiftUI

enum AppRoute: Hashable {
    case fileBrowser
    case filteredFiles(ext: String)
    case folderBrowser
    case folderDetail(name: String)
}

struct FileViewNavID: Hashable {
    let id: Int
}

// MARK: - File Browser (category picker)

struct FileBrowserView: View {
    private let categories: [(String, String, String, Color)] = [
        (".swift Files", "swift", "swift", Earthly.Iron._300),
        (".py Files", "chevron.left.forwardslash.chevron.right", "py", Earthly.Ochre._300),
        (".md Files", "doc.richtext", "md", Earthly.Lichen._300),
    ]

    var body: some View {
        ZStack {
            Earthly.BG.primary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element.2) { index, cat in
                        NavigationLink(value: AppRoute.filteredFiles(ext: cat.2)) {
                            HStack(spacing: Earthly.Spacing.base) {
                                RoundedRectangle(cornerRadius: Earthly.Radius.lg, style: .continuous)
                                    .fill(cat.3.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: cat.1)
                                            .font(.system(size: 16))
                                            .foregroundStyle(cat.3)
                                    )

                                Text(cat.0)
                                    .font(.earthlyHeadline())
                                    .foregroundStyle(Earthly.Text.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Earthly.Border.strong)
                            }
                            .padding(.horizontal, Earthly.Spacing.lg)
                            .padding(.vertical, Earthly.Spacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < categories.count - 1 {
                            Divider()
                                .background(Earthly.Border.subtle)
                                .padding(.leading, 72)
                        }
                    }
                }
                .background(Earthly.Surface._1)
                .clipShape(RoundedRectangle(cornerRadius: Earthly.Radius.xxl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Earthly.Radius.xxl, style: .continuous)
                        .stroke(Earthly.Border.subtle, lineWidth: 1)
                )
                .padding(.horizontal, Earthly.Spacing.lg)
                .padding(.top, Earthly.Spacing.sm)
                .padding(.bottom, Earthly.Spacing.xxl)
            }
        }
        .navigationTitle("All Files")
        .navigationBarTitleDisplayMode(.large)
        .earthlyNavBar()
    }
}

// MARK: - Filtered Files List

struct FilteredFilesView: View {
    let ext: String

    @State private var files: [FileRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var filteredFiles: [FileRecord] {
        let byExt = files.filter { $0.extension_ == ext }
        if searchText.isEmpty { return byExt }
        return byExt.filter { file in
            file.filename.localizedCaseInsensitiveContains(searchText) ||
            (file.folder ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Earthly.BG.primary.ignoresSafeArea()

            Group {
                if isLoading {
                    loadingView
                } else if filteredFiles.isEmpty && searchText.isEmpty {
                    emptyView
                } else if filteredFiles.isEmpty {
                    noResultsView
                } else {
                    fileList
                }
            }
        }
        .navigationTitle(".\(ext) Files")
        .navigationBarTitleDisplayMode(.large)
        .earthlyNavBar()
        .searchable(text: $searchText, prompt: "Search files...")
        .task {
            await loadFiles()
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: Earthly.Spacing.base) {
            ProgressView()
                .tint(Earthly.Accent.primary)
                .scaleEffect(1.2)
            Text("Loading files...")
                .font(.earthlyCaption())
                .foregroundStyle(Earthly.Text.tertiary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No .\(ext) Files", systemImage: "doc")
        } description: {
            Text("Files with the .\(ext) extension will appear here")
        } actions: {
            Button {
                Task { await loadFiles() }
            } label: {
                Text("Refresh")
            }
        }
        .foregroundStyle(Earthly.Text.secondary)
    }

    private var noResultsView: some View {
        ContentUnavailableView.search(text: searchText)
            .foregroundStyle(Earthly.Text.secondary)
    }

    // MARK: - List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredFiles) { file in
                    NavigationLink(value: FileViewNavID(id: file.id)) {
                        fileRow(file)
                    }
                    .buttonStyle(.plain)

                    if file.id != filteredFiles.last?.id {
                        Divider()
                            .background(Earthly.Border.subtle)
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Earthly.Surface._1)
            .clipShape(RoundedRectangle(cornerRadius: Earthly.Radius.xxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Earthly.Radius.xxl, style: .continuous)
                    .stroke(Earthly.Border.subtle, lineWidth: 1)
            )
            .padding(.horizontal, Earthly.Spacing.lg)
            .padding(.top, Earthly.Spacing.sm)
            .padding(.bottom, Earthly.Spacing.xxl)
        }
        .refreshable {
            await loadFiles()
        }
    }

    private func fileRow(_ file: FileRecord) -> some View {
        HStack(spacing: Earthly.Spacing.base) {
            fileIcon(file)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.filename)
                    .font(.earthlyHeadline())
                    .foregroundStyle(Earthly.Text.primary)
                    .lineLimit(1)

                HStack(spacing: Earthly.Spacing.sm) {
                    if let folder = file.folder, !folder.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 9))
                            Text(folder)
                        }
                        .foregroundStyle(Earthly.Ochre._300)
                    }

                    Text(file.sizeFormatted)
                        .foregroundStyle(Earthly.Text.tertiary)

                    Text(file.formattedDate)
                        .foregroundStyle(Earthly.Text.disabled)
                }
                .font(.system(size: 11))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Earthly.Border.strong)
        }
        .padding(.horizontal, Earthly.Spacing.lg)
        .padding(.vertical, Earthly.Spacing.md)
        .contentShape(Rectangle())
    }

    private func fileIcon(_ file: FileRecord) -> some View {
        let color = fileExtColor(file.extension_)
        return RoundedRectangle(cornerRadius: Earthly.Radius.lg, style: .continuous)
            .fill(color.opacity(0.12))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: file.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            )
    }

    // MARK: - Data

    private func loadFiles() async {
        isLoading = files.isEmpty
        errorMessage = nil
        do {
            files = try await FilesService.fetchFiles()
        } catch {
            errorMessage = "Failed to load files"
        }
        isLoading = false
    }
}

private func fileExtColor(_ ext: String) -> Color {
    switch ext {
    case "py": return Earthly.Ochre._300
    case "swift": return Earthly.Iron._300
    case "md": return Earthly.Lichen._300
    default: return Earthly.Accent.cool
    }
}
