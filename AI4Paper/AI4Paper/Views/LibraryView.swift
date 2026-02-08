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

    private var sortedFolders: [LibraryFolder] {
        libraryStore.folders.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var filteredPapers: [LibraryItemViewData] {
        var items = appState.libraryItems()

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

    private func paperCount(in folder: LibraryFolder) -> Int {
        libraryStore.metas.values.filter { $0.folderId == folder.id }.count
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
                onSave: saveFolder
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
            BatchMoveView(
                folders: libraryStore.folders,
                onCancel: { isBatchMovePresented = false },
                onMove: batchMoveToFolder
            )
        }
    }

    // ── List ──

    private var listContent: some View {
        List(selection: $selection) {
            // ── 文件夹区 ──
            if !sortedFolders.isEmpty && !editMode.isEditing {
                Section {
                    ForEach(sortedFolders) { folder in
                        NavigationLink {
                            FolderPapersView(folder: folder)
                        } label: {
                            Label {
                                HStack {
                                    Text(folder.name)
                                    Spacer()
                                    Text("\(paperCount(in: folder))")
                                        .foregroundStyle(.tertiary)
                                }
                            } icon: {
                                Image(systemName: "folder.fill")
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
                    .onDelete(perform: deleteFolders)
                } header: {
                    Text("文件夹")
                }
            }

            // ── 论文区 ──
            let items = filteredPapers
            if items.isEmpty {
                Section {
                    EmptyResultView()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(items) { item in
                        paperRow(item)
                            .tag(item.id)
                            .draggable(item.id)
                    }
                    .onDelete { offsets in
                        deleteItems(offsets, in: items)
                    }
                } header: {
                    Text("论文（\(items.count)）")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // ── Paper Row ──

    private func paperRow(_ item: LibraryItemViewData) -> some View {
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
                        if let name = libraryStore.folderName(for: item.meta.folderId) {
                            Label(name, systemImage: "folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !item.meta.tags.isEmpty {
                            Text(item.meta.tags.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !editMode.isEditing {
                    Spacer()
                    paperMenu(for: item)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func paperMenu(for item: LibraryItemViewData) -> some View {
        Menu {
            if !libraryStore.folders.isEmpty {
                Menu("移入文件夹") {
                    Button("无文件夹") {
                        libraryStore.updateFolder(for: item.id, folderId: nil)
                    }
                    Divider()
                    ForEach(libraryStore.folders) { folder in
                        Button(folder.name) {
                            libraryStore.updateFolder(for: item.id, folderId: folder.id)
                        }
                    }
                }
                Divider()
            }
            Button("标记为未读") { libraryStore.updateStatus(for: item.id, status: .unread) }
            Button("标记为在读") { libraryStore.updateStatus(for: item.id, status: .reading) }
            Button("标记为已读") { libraryStore.updateStatus(for: item.id, status: .finished) }
            Divider()
            Button("编辑标签") { presentTagEditor(for: item) }
            Divider()
            Button("删除", role: .destructive) { appState.removeSaved(id: item.id) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
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

    private func saveFolder() {
        _ = libraryStore.addFolder(name: newFolderName)
        newFolderName = ""
        isCreateFolderPresented = false
    }

    private func saveTags() {
        guard let editingPaperId else { return }
        let tags = tagEditorText.split(separator: ",").map(String.init)
        libraryStore.updateTags(for: editingPaperId, tags: tags)
        isTagEditorPresented = false
    }

    private func presentTagEditor(for item: LibraryItemViewData) {
        editingPaperId = item.id
        tagEditorText = item.meta.tags.joined(separator: ", ")
        isTagEditorPresented = true
    }

    private func deleteItems(_ offsets: IndexSet, in items: [LibraryItemViewData]) {
        for index in offsets { appState.removeSaved(id: items[index].id) }
    }

    private func deleteFolders(at offsets: IndexSet) {
        let sorted = sortedFolders
        for index in offsets { libraryStore.removeFolder(id: sorted[index].id) }
    }

    private func batchMoveToFolder(_ folderId: String?) {
        for id in selection { libraryStore.updateFolder(for: id, folderId: folderId) }
        selection.removeAll()
        isBatchMovePresented = false
        editMode = .inactive
    }
}

// MARK: - FolderPapersView (文件夹内容页)

private struct FolderPapersView: View {
    let folder: LibraryFolder
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<String>()
    @State private var isBatchMovePresented = false
    @State private var isTagEditorPresented = false
    @State private var tagEditorText = ""
    @State private var editingPaperId: String?

    private var papersInFolder: [LibraryItemViewData] {
        appState.libraryItems()
            .filter { $0.meta.folderId == folder.id }
            .sorted { $0.meta.savedAt > $1.meta.savedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            let items = papersInFolder
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("文件夹是空的")
                        .font(.headline)
                    Text("在知识库中通过菜单或拖拽将论文移入")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(items) { item in
                        folderPaperRow(item)
                            .tag(item.id)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            libraryStore.updateFolder(for: items[index].id, folderId: nil)
                        }
                    }
                }
                .listStyle(.plain)
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
        }
        .onAppear { libraryStore.activeFolderId = folder.id }
        .sheet(isPresented: $isBatchMovePresented) {
            BatchMoveView(
                folders: libraryStore.folders.filter { $0.id != folder.id },
                onCancel: { isBatchMovePresented = false },
                onMove: { folderId in
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

    // ── Paper Row (in folder) ──

    private func folderPaperRow(_ item: LibraryItemViewData) -> some View {
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
                    Menu {
                        Menu("移至其他文件夹") {
                            Button("无文件夹") {
                                libraryStore.updateFolder(for: item.id, folderId: nil)
                            }
                            Divider()
                            ForEach(libraryStore.folders.filter { $0.id != folder.id }) { f in
                                Button(f.name) {
                                    libraryStore.updateFolder(for: item.id, folderId: f.id)
                                }
                            }
                        }
                        Divider()
                        Button("标记为未读") { libraryStore.updateStatus(for: item.id, status: .unread) }
                        Button("标记为在读") { libraryStore.updateStatus(for: item.id, status: .reading) }
                        Button("标记为已读") { libraryStore.updateStatus(for: item.id, status: .finished) }
                        Divider()
                        Button("编辑标签") {
                            editingPaperId = item.id
                            tagEditorText = item.meta.tags.joined(separator: ", ")
                            isTagEditorPresented = true
                        }
                        Divider()
                        Button("移出文件夹") {
                            libraryStore.updateFolder(for: item.id, folderId: nil)
                        }
                        Button("删除收藏", role: .destructive) {
                            appState.removeSaved(id: item.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // ── Batch Bar (in folder) ──

    private var folderBatchBar: some View {
        HStack(spacing: 16) {
            Button {
                isBatchMovePresented = true
            } label: {
                Label("移至其他文件夹", systemImage: "folder")
            }

            Button {
                for id in selection {
                    libraryStore.updateFolder(for: id, folderId: nil)
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

// MARK: - BatchMoveView

private struct BatchMoveView: View {
    let folders: [LibraryFolder]
    let onCancel: () -> Void
    let onMove: (String?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onMove(nil)
                } label: {
                    Label("无文件夹（移出）", systemImage: "tray")
                }

                ForEach(folders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { folder in
                    Button {
                        onMove(folder.id)
                    } label: {
                        Label(folder.name, systemImage: "folder.fill")
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
