import SwiftUI

struct NoteListView: View {
    var auth: AuthService
    @State private var showAccount = false
    @State private var showNewFile = false
    @State private var showNewFolder = false
    @State private var path = NavigationPath()

    private let fileTypes: [(String, String, Color)] = [
        ("Python", ".py", Earthly.Ochre._300),
        ("Swift", ".swift", Earthly.Iron._300),
        ("Markdown", ".md", Earthly.Lichen._300),
    ]

    private let actions: [(String, String, String)] = [
        ("New File", "doc.badge.plus", "Create a new file"),
        ("New Folder", "folder.badge.plus", "Organize your files"),
        ("Open File", "doc", "Browse saved files"),
        ("Open Folder", "folder", "Browse saved folders"),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Earthly.BG.primary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Earthly.Spacing.xl) {
                        // Welcome header
                        VStack(spacing: Earthly.Spacing.md) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(Earthly.Accent.primary)

                            Text("Welcome")
                                .font(.earthlyTitle())
                                .foregroundStyle(Earthly.Text.primary)

                            Text("Store and manage your files.\nSupported formats:")
                                .font(.earthlyCaption())
                                .foregroundStyle(Earthly.Text.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Earthly.Spacing.lg)

                        // File type tags
                        HStack(spacing: Earthly.Spacing.sm) {
                            ForEach(fileTypes, id: \.0) { name, ext, color in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 6, height: 6)
                                    Text(ext)
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(color)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(color.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(color.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }

                        // Action buttons
                        VStack(spacing: 0) {
                            ForEach(Array(actions.enumerated()), id: \.element.0) { index, action in
                                Button {
                                    handleAction(action.0)
                                } label: {
                                    HStack(spacing: Earthly.Spacing.base) {
                                        RoundedRectangle(cornerRadius: Earthly.Radius.lg, style: .continuous)
                                            .fill(Earthly.Iron._300.opacity(0.12))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: action.1)
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(Earthly.Iron._300)
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(action.0)
                                                .font(.earthlyHeadline())
                                                .foregroundStyle(Earthly.Text.primary)
                                            Text(action.2)
                                                .font(.system(size: 12))
                                                .foregroundStyle(Earthly.Text.tertiary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Earthly.Border.strong)
                                    }
                                    .padding(.horizontal, Earthly.Spacing.lg)
                                    .padding(.vertical, Earthly.Spacing.base)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < actions.count - 1 {
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
                    }
                    .padding(.bottom, Earthly.Spacing.xxl)
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAccount = true
                    } label: {
                        Image(systemName: auth.isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(auth.isLoggedIn ? Earthly.Accent.primary : Earthly.Text.tertiary)
                    }
                }
            }
            .sheet(isPresented: $showAccount) {
                AccountSheet(auth: auth)
            }
            .sheet(isPresented: $showNewFile) {
                NewFileSheet(folder: nil) { record in
                    path.append(FileViewNavID(id: record.id))
                }
            }
            .sheet(isPresented: $showNewFolder) {
                NewFolderSheet { folderName in
                    path.append(AppRoute.folderDetail(name: folderName))
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .fileBrowser:
                    FileBrowserView()
                case .filteredFiles(let ext):
                    FilteredFilesView(ext: ext)
                case .folderBrowser:
                    FolderBrowserView()
                case .folderDetail(let name):
                    FolderDetailView(folderName: name)
                }
            }
            .navigationDestination(for: FileViewNavID.self) { nav in
                FileViewerView(fileId: nav.id)
            }
            .earthlyNavBar()
        }
        .tint(Earthly.Accent.primary)
    }

    private func handleAction(_ name: String) {
        switch name {
        case "New File":
            showNewFile = true
        case "New Folder":
            showNewFolder = true
        case "Open File":
            path.append(AppRoute.fileBrowser)
        case "Open Folder":
            path.append(AppRoute.folderBrowser)
        default:
            break
        }
    }
}
