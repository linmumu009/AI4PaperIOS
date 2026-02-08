import SwiftUI

// MARK: - LibraryView (Root)

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var searchText = ""
    @State private var sortOption: LibrarySortOption = .recentSaved
    @State private var statusFilter: LibraryStatusFilter = .all

    @State private var isCreateFolderPresented = false
    @State private var newFolderName = ""
    @State private var isTagEditorPresented = false
    @State private var tagEditorText = ""
    @State private var editingPaperId: String?

    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<String>()
    @State private var isBatchMovePresented = false

    // ── Computed ──

    /// 顶级文件夹（parentId == nil）
    private var topLevelFolders: [LibraryFolder] {
        libraryStore.childFolders(of: nil)
    }

    /// 未归入任何文件夹的论文
    private var unfilteredPapers: [LibraryItemViewData] {
        var items = appState.libraryItems().filter { $0.meta.folderId == nil }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            items = items.filter {
                $0.paper.displayTitle.lowercased().contains(query)
                || $0.paper.summaryText.lowercased().contains(query)
                || $0.meta.tags.joined(separator: " ").lowercased().contains(query)
            }
        }

        if let requiredStatus = statusFilter.status {
            items = items.filter { $0.meta.status == requiredStatus }
        }

        switch sortOption {
        case .recentSaved:   items.sort { $0.meta.savedAt > $1.meta.savedAt }
        case .recentUpdated: items.sort { $0.meta.updatedAt > $1.meta.updatedAt }
        case .title:         items.sort { $0.paper.displayTitle.localizedStandardCompare($1.paper.displayTitle) == .orderedAscending }
        case .source:        items.sort { $0.paper.source.localizedStandardCompare($1.paper.source) == .orderedAscending }
        }
        return items
    }

    // ── Body ──

    var body: some View {
        VStack(spacing: 0) {
            if appState.savedPapers.isEmpty && libraryStore.folders.isEmpty {
                EmptyLibraryView()
            } else {
                listContent
            }

            if editMode.isEditing && !selection.isEmpty {
                batchActionBar
            }
        }
        .navigationTitle("知识库")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .environment(\.editMode, $editMode)
        .toolbar { toolbarContent }
        .onAppear { libraryStore.activeFolderId = nil }
        .sheet(isPresented: $isCreateFolderPresented) {
            FolderEditorView(
                text: $newFolderName,
                onCancel: { isCreateFolderPresented = false },
                onSave: { saveFolder(parentId: nil) }
            )
        }
        .sheet(isPresented: $isTagEditorPresented) {
            TagEditorView(
                text: $tagEditorText,
                onCancel: { isTagEditorPresented = false },
                onSave: saveTags
            )
        }
        .sheet(isPresented: $isBatchMovePresented) {
            FolderPickerView(
                libraryStore: libraryStore,
                excludeFolderId: nil,
                onCancel: { isBatchMovePresented = false },
                onPick: batchMoveToFolder
            )
        }
    }

    // ── List ──

    private var listContent: some View {
        List(selection: $selection) {
            // ── 文件夹区 ──
            if !topLevelFolders.isEmpty && !editMode.isEditing {
                Section {
                    ForEach(topLevelFolders) { folder in
                        FolderRow(folder: folder)
                    }
                    .onDelete(perform: deleteTopLevelFolders)
                } header: {
                    Text("文件夹")
                }
            }

            // ── 未归档论文区 ──
            let items = unfilteredPapers
            if items.isEmpty && topLevelFolders.isEmpty {
                Section {
                    EmptyResultView()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else if !items.isEmpty {
                Section {
                    ForEach(items) { item in
                        PaperRow(item: item, editMode: editMode, currentFolderId: nil)
                            .tag(item.id)
                            .draggable(item.id)
                    }
                    .onDelete { offsets in
                        for index in offsets { appState.removeSaved(id: items[index].id) }
                    }
                } header: {
                    Text("未归档论文（\(items.count)）")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // ── Batch Action Bar ──

    private var batchActionBar: some View {
        HStack(spacing: 16) {
            Button {
                isBatchMovePresented = true
            } label: {
                Label("移入文件夹", systemImage: "folder")
            }

            Divider().frame(height: 24)

            Button(role: .destructive) {
                for id in selection { appState.removeSaved(id: id) }
                selection.removeAll()
                editMode = .inactive
            } label: {
                Label("删除", systemImage: "trash")
            }

            Spacer()

            Text("已选 \(selection.count) 项")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // ── Toolbar ──

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                withAnimation {
                    if editMode.isEditing {
                        editMode = .inactive
                        selection.removeAll()
                    } else {
                        editMode = .active
                    }
                }
            } label: {
                Text(editMode.isEditing ? "完成" : "选择")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button { isCreateFolderPresented = true } label: {
                Image(systemName: "folder.badge.plus")
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Picker("排序", selection: $sortOption) {
                    ForEach(LibrarySortOption.allCases, id: \.self) {
                        Text($0.title).tag($0)
                    }
                }
                Divider()
                Picker("状态", selection: $statusFilter) {
                    ForEach(LibraryStatusFilter.allCases, id: \.self) {
                        Text($0.title).tag($0)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }

    // ── Actions ──

    private func saveFolder(parentId: String?) {
        _ = libraryStore.addFolder(name: newFolderName, parentId: parentId)
        newFolderName = ""
        isCreateFolderPresented = false
    }

    private func saveTags() {
        guard let editingPaperId else { return }
        let tags = tagEditorText.split(separator: ",").map(String.init)
        libraryStore.updateTags(for: editingPaperId, tags: tags)
        isTagEditorPresented = false
    }

    private func deleteTopLevelFolders(at offsets: IndexSet) {
        let sorted = topLevelFolders
        for index in offsets { libraryStore.removeFolder(id: sorted[index].id) }
    }

    private func batchMoveToFolder(_ folderId: String?) {
        for id in selection { libraryStore.updateFolder(for: id, folderId: folderId) }
        selection.removeAll()
        isBatchMovePresented = false
        editMode = .inactive
    }
}

// MARK: - FolderContentsView (文件夹内容页，支持无限嵌套)

struct FolderContentsView: View {
    let folder: LibraryFolder
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<String>()
    @State private var isBatchMovePresented = false
    @State private var isCreateSubfolderPresented = false
    @State private var newSubfolderName = ""
    @State private var isTagEditorPresented = false
    @State private var tagEditorText = ""
    @State private var editingPaperId: String?

    private var childFolders: [LibraryFolder] {
        libraryStore.childFolders(of: folder.id)
    }

    private var papersInFolder: [LibraryItemViewData] {
        appState.libraryItems()
            .filter { $0.meta.folderId == folder.id }
            .sorted { $0.meta.savedAt > $1.meta.savedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            let papers = papersInFolder
            let subfolders = childFolders

            if papers.isEmpty && subfolders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("文件夹是空的")
                        .font(.headline)
                    Text("通过菜单或拖拽将论文移入，\n或创建子文件夹")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    // ── 子文件夹 ──
                    if !subfolders.isEmpty && !editMode.isEditing {
                        Section {
                            ForEach(subfolders) { child in
                                FolderRow(folder: child)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    libraryStore.removeFolder(id: subfolders[index].id)
                                }
                            }
                        } header: {
                            Text("子文件夹")
                        }
                    }

                    // ── 论文 ──
                    if !papers.isEmpty {
                        Section {
                            ForEach(papers) { item in
                                PaperRow(item: item, editMode: editMode, currentFolderId: folder.id)
                                    .tag(item.id)
                                    .draggable(item.id)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    libraryStore.updateFolder(for: papers[index].id, folderId: folder.parentId)
                                }
                            }
                        } header: {
                            Text("论文（\(papers.count)）")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            if editMode.isEditing && !selection.isEmpty {
                folderBatchBar
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        if editMode.isEditing {
                            editMode = .inactive
                            selection.removeAll()
                        } else {
                            editMode = .active
                        }
                    }
                } label: {
                    Text(editMode.isEditing ? "完成" : "选择")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { isCreateSubfolderPresented = true } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .onAppear { libraryStore.activeFolderId = folder.id }
        .sheet(isPresented: $isCreateSubfolderPresented) {
            FolderEditorView(
                text: $newSubfolderName,
                onCancel: { isCreateSubfolderPresented = false },
                onSave: {
                    _ = libraryStore.addFolder(name: newSubfolderName, parentId: folder.id)
                    newSubfolderName = ""
                    isCreateSubfolderPresented = false
                }
            )
        }
        .sheet(isPresented: $isBatchMovePresented) {
            FolderPickerView(
                libraryStore: libraryStore,
                excludeFolderId: nil,
                onCancel: { isBatchMovePresented = false },
                onPick: { folderId in
                    for id in selection {
                        libraryStore.updateFolder(for: id, folderId: folderId)
                    }
                    selection.removeAll()
                    isBatchMovePresented = false
                    editMode = .inactive
                }
            )
        }
        .sheet(isPresented: $isTagEditorPresented) {
            TagEditorView(
                text: $tagEditorText,
                onCancel: { isTagEditorPresented = false },
                onSave: {
                    guard let editingPaperId else { return }
                    let tags = tagEditorText.split(separator: ",").map(String.init)
                    libraryStore.updateTags(for: editingPaperId, tags: tags)
                    isTagEditorPresented = false
                }
            )
        }
    }

    private var folderBatchBar: some View {
        HStack(spacing: 16) {
            Button {
                isBatchMovePresented = true
            } label: {
                Label("移动", systemImage: "folder")
            }

            Button {
                for id in selection {
                    libraryStore.updateFolder(for: id, folderId: folder.parentId)
                }
                selection.removeAll()
                editMode = .inactive
            } label: {
                Label("移出", systemImage: "folder.badge.minus")
            }

            Button(role: .destructive) {
                for id in selection { appState.removeSaved(id: id) }
                selection.removeAll()
                editMode = .inactive
            } label: {
                Label("删除", systemImage: "trash")
            }

            Spacer()

            Text("已选 \(selection.count) 项")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - FolderRow (可复用的文件夹行)

private struct FolderRow: View {
    let folder: LibraryFolder
    @EnvironmentObject private var libraryStore: LibraryStore

    var body: some View {
        NavigationLink {
            FolderContentsView(folder: folder)
        } label: {
            Label {
                HStack {
                    Text(folder.name)
                    Spacer()
                    let subCount = libraryStore.childFolderCount(of: folder.id)
                    let paperCount = libraryStore.totalPaperCount(in: folder.id)
                    if subCount > 0 {
                        Text("\(subCount) 个子文件夹")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text("\(paperCount)")
                        .foregroundStyle(.tertiary)
                }
            } icon: {
                Image(systemName: libraryStore.childFolderCount(of: folder.id) > 0
                      ? "folder.fill"
                      : "folder.fill")
                    .foregroundStyle(.blue)
            }
        }
        .dropDestination(for: String.self) { ids, _ in
            for id in ids {
                libraryStore.updateFolder(for: id, folderId: folder.id)
            }
            return true
        }
    }
}

// MARK: - PaperRow (可复用的论文行)

private struct PaperRow: View {
    let item: LibraryItemViewData
    let editMode: EditMode
    let currentFolderId: String?
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore

    var body: some View {
        NavigationLink {
            PaperDetailView(paper: item.paper)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.paper.headerLine)
                        .font(.headline)
                        .lineLimit(2)
                    Text(item.paper.summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        StatusBadge(status: item.meta.status)
                        if !item.meta.tags.isEmpty {
                            Text(item.meta.tags.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !editMode.isEditing {
                    Spacer()
                    paperMenu
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var paperMenu: some View {
        Menu {
            if !libraryStore.folders.isEmpty {
                Menu("移入文件夹") {
                    Button("无文件夹（根目录）") {
                        libraryStore.updateFolder(for: item.id, folderId: nil)
                    }
                    Divider()
                    let tree = libraryStore.flatFolderTree(excludingDescendantsOf: nil)
                    ForEach(tree, id: \.folder.id) { entry in
                        Button {
                            libraryStore.updateFolder(for: item.id, folderId: entry.folder.id)
                        } label: {
                            Text(String(repeating: "  ", count: entry.depth) + entry.folder.name)
                        }
                    }
                }
                Divider()
            }
            Button("标记为未读") { libraryStore.updateStatus(for: item.id, status: .unread) }
            Button("标记为在读") { libraryStore.updateStatus(for: item.id, status: .reading) }
            Button("标记为已读") { libraryStore.updateStatus(for: item.id, status: .finished) }
            Divider()
            if currentFolderId != nil {
                Button("移出当前文件夹") {
                    // 移到上一级
                    let parent = libraryStore.folders.first(where: { $0.id == currentFolderId })?.parentId
                    libraryStore.updateFolder(for: item.id, folderId: parent)
                }
                Divider()
            }
            Button("删除收藏", role: .destructive) { appState.removeSaved(id: item.id) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - FolderPickerView (层级文件夹选择器)

private struct FolderPickerView: View {
    let libraryStore: LibraryStore
    let excludeFolderId: String?
    let onCancel: () -> Void
    let onPick: (String?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onPick(nil)
                } label: {
                    Label("根目录（无文件夹）", systemImage: "tray")
                }

                let tree = libraryStore.flatFolderTree(excludingDescendantsOf: excludeFolderId)
                ForEach(tree, id: \.folder.id) { entry in
                    Button {
                        onPick(entry.folder.id)
                    } label: {
                        HStack(spacing: 0) {
                            ForEach(0..<entry.depth, id: \.self) { _ in
                                Text("    ")
                            }
                            Label(entry.folder.name, systemImage: "folder.fill")
                        }
                    }
                }
            }
            .navigationTitle("选择目标文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
            }
        }
    }
}

// MARK: - StatusBadge

private struct StatusBadge: View {
    let status: LibraryReadStatus

    private var color: Color {
        switch status {
        case .unread:   return .orange
        case .reading:  return .blue
        case .finished: return .green
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

// MARK: - Enums

private enum LibrarySortOption: String, CaseIterable {
    case recentSaved
    case recentUpdated
    case title
    case source

    var title: String {
        switch self {
        case .recentSaved:   return "最近收藏"
        case .recentUpdated: return "最近更新"
        case .title:         return "标题"
        case .source:        return "来源"
        }
    }
}

private enum LibraryStatusFilter: String, CaseIterable {
    case all
    case unread
    case reading
    case finished

    var title: String {
        switch self {
        case .all:      return "全部"
        case .unread:   return "未读"
        case .reading:  return "在读"
        case .finished: return "已读"
        }
    }

    var status: LibraryReadStatus? {
        switch self {
        case .all:      return nil
        case .unread:   return .unread
        case .reading:  return .reading
        case .finished: return .finished
        }
    }
}

// MARK: - Editors

private struct TagEditorView: View {
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("标签（用逗号分隔）", text: $text)
                }
            }
            .navigationTitle("编辑标签")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: onSave)
                }
            }
        }
    }
}

private struct FolderEditorView: View {
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("文件夹名称", text: $text)
                }
            }
            .navigationTitle("新建文件夹")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建", action: onSave)
                }
            }
        }
    }
}

// MARK: - Empty States

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("暂无收藏")
                .font(.headline)
            Text("右滑即可把论文加入知识库")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct EmptyResultView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("没有匹配结果")
                .font(.headline)
            Text("尝试修改搜索或筛选条件")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
