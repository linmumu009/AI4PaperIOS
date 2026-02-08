import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var searchText = ""
    @State private var sortOption: LibrarySortOption = .recentSaved
    @State private var statusFilter: LibraryStatusFilter = .all
    @State private var selectedFolderId: String?
    @State private var selectedTag: String?
    @State private var grouping: LibraryGrouping = .none

    @State private var isTagEditorPresented = false
    @State private var isCreateFolderPresented = false
    @State private var tagEditorText = ""
    @State private var editingPaperId: String?
    @State private var newFolderName = ""

    var body: some View {
        Group {
            if appState.savedPapers.isEmpty {
                EmptyLibraryView()
            } else {
                contentView
            }
        }
        .navigationTitle("知识库")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isCreateFolderPresented = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("排序", selection: $sortOption) {
                        ForEach(LibrarySortOption.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("状态", selection: $statusFilter) {
                        ForEach(LibraryStatusFilter.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("分组", selection: $grouping) {
                        ForEach(LibraryGrouping.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Divider()
                    Menu("文件夹筛选") {
                        Button("全部文件夹") { selectedFolderId = nil }
                        ForEach(libraryStore.folders) { folder in
                            Button(folder.name) { selectedFolderId = folder.id }
                        }
                    }
                    Menu("标签筛选") {
                        Button("全部标签") { selectedTag = nil }
                        ForEach(libraryStore.allTags, id: \.self) { tag in
                            Button(tag) { selectedTag = tag }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $isTagEditorPresented) {
            TagEditorView(
                text: $tagEditorText,
                onCancel: { isTagEditorPresented = false },
                onSave: saveTags
            )
        }
        .sheet(isPresented: $isCreateFolderPresented) {
            FolderEditorView(
                text: $newFolderName,
                onCancel: { isCreateFolderPresented = false },
                onSave: saveFolder
            )
        }
    }

    private var contentView: some View {
        let items = filteredItems
        return Group {
            if items.isEmpty {
                EmptyResultView()
            } else {
                List {
                    switch grouping {
                    case .none:
                        listItems(items)
                    case .folder:
                        groupedByFolder(items)
                    case .tag:
                        groupedByTag(items)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var filteredItems: [LibraryItemViewData] {
        var items = appState.libraryItems()

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            items = items.filter { item in
                let title = item.paper.displayTitle.lowercased()
                let summary = item.paper.summaryText.lowercased()
                let tags = item.meta.tags.joined(separator: " ").lowercased()
                return title.contains(query) || summary.contains(query) || tags.contains(query)
            }
        }

        if let requiredStatus = statusFilter.status {
            items = items.filter { $0.meta.status == requiredStatus }
        }

        if let selectedFolderId {
            items = items.filter { $0.meta.folderId == selectedFolderId }
        }

        if let selectedTag {
            items = items.filter { $0.meta.tags.contains(selectedTag) }
        }

        switch sortOption {
        case .recentSaved:
            items.sort { $0.meta.savedAt > $1.meta.savedAt }
        case .recentUpdated:
            items.sort { $0.meta.updatedAt > $1.meta.updatedAt }
        case .title:
            items.sort { $0.paper.displayTitle.localizedStandardCompare($1.paper.displayTitle) == .orderedAscending }
        case .source:
            items.sort { $0.paper.source.localizedStandardCompare($1.paper.source) == .orderedAscending }
        }

        return items
    }

    @ViewBuilder
    private func listItems(_ items: [LibraryItemViewData]) -> some View {
        ForEach(items, id: \.id) { item in
            itemRow(item)
        }
        .onDelete { offsets in
            deleteItems(offsets, in: items)
        }
    }

    @ViewBuilder
    private func groupedByFolder(_ items: [LibraryItemViewData]) -> some View {
        let groups = Dictionary(grouping: items) { item in
            libraryStore.folderName(for: item.meta.folderId) ?? "未分组"
        }
        let sortedKeys = groups.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        ForEach(sortedKeys, id: \.self) { key in
            Section(header: Text(key)) {
                if let sectionItems = groups[key] {
                    ForEach(sectionItems, id: \.id) { item in
                        itemRow(item)
                    }
                    .onDelete { offsets in
                        deleteItems(offsets, in: sectionItems)
                    }
                }
            }
        }
    }

    private func tagGroups(from items: [LibraryItemViewData]) -> [(key: String, items: [LibraryItemViewData])] {
        var groups: [String: [LibraryItemViewData]] = [:]
        for item in items {
            if item.meta.tags.isEmpty {
                groups["无标签", default: []].append(item)
            } else {
                for tag in item.meta.tags {
                    groups[tag, default: []].append(item)
                }
            }
        }
        return groups.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { (key: $0, items: groups[$0]!) }
    }

    @ViewBuilder
    private func groupedByTag(_ items: [LibraryItemViewData]) -> some View {
        let groups = tagGroups(from: items)
        ForEach(groups, id: \.key) { group in
            Section(header: Text(group.key)) {
                ForEach(group.items, id: \.id) { item in
                    itemRow(item)
                }
                .onDelete { offsets in
                    deleteItems(offsets, in: group.items)
                }
            }
        }
    }

    private func itemRow(_ item: LibraryItemViewData) -> some View {
        NavigationLink {
            PaperDetailView(paper: item.paper)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.paper.headerLine)
                    .font(.headline)
                    .lineLimit(2)
                Text(item.paper.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(item.meta.status.displayName)
                    if let folderName = libraryStore.folderName(for: item.meta.folderId) {
                        Text(folderName)
                    }
                    if !item.meta.tags.isEmpty {
                        Text(item.meta.tags.joined(separator: " · "))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .contextMenu {
            Button("标记为未读") { libraryStore.updateStatus(for: item.id, status: .unread) }
            Button("标记为在读") { libraryStore.updateStatus(for: item.id, status: .reading) }
            Button("标记为已读") { libraryStore.updateStatus(for: item.id, status: .finished) }
            Divider()
            Button("编辑标签") { presentTagEditor(for: item) }
            Menu("设置分组") {
                Button("无分组") { libraryStore.updateFolder(for: item.id, folderId: nil) }
                ForEach(libraryStore.folders) { folder in
                    Button(folder.name) { libraryStore.updateFolder(for: item.id, folderId: folder.id) }
                }
            }
        }
    }

    private func presentTagEditor(for item: LibraryItemViewData) {
        editingPaperId = item.id
        tagEditorText = item.meta.tags.joined(separator: ", ")
        isTagEditorPresented = true
    }

    private func saveTags() {
        guard let editingPaperId else { return }
        let tags = tagEditorText
            .split(separator: ",")
            .map { String($0) }
        libraryStore.updateTags(for: editingPaperId, tags: tags)
        isTagEditorPresented = false
    }

    private func saveFolder() {
        let created = libraryStore.addFolder(name: newFolderName)
        newFolderName = ""
        isCreateFolderPresented = false
        if let created {
            selectedFolderId = created.id
        }
    }

    private func deleteItems(_ offsets: IndexSet, in items: [LibraryItemViewData]) {
        for index in offsets {
            let id = items[index].paper.id
            appState.removeSaved(id: id)
        }
    }
}

private enum LibrarySortOption: String, CaseIterable {
    case recentSaved
    case recentUpdated
    case title
    case source

    var title: String {
        switch self {
        case .recentSaved: return "最近收藏"
        case .recentUpdated: return "最近更新"
        case .title: return "标题"
        case .source: return "来源"
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
        case .all: return "全部"
        case .unread: return "未读"
        case .reading: return "在读"
        case .finished: return "已读"
        }
    }

    var status: LibraryReadStatus? {
        switch self {
        case .all: return nil
        case .unread: return .unread
        case .reading: return .reading
        case .finished: return .finished
        }
    }
}

private enum LibraryGrouping: String, CaseIterable {
    case none
    case folder
    case tag

    var title: String {
        switch self {
        case .none: return "不分组"
        case .folder: return "按文件夹"
        case .tag: return "按标签"
        }
    }
}

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
                    TextField("分组名称", text: $text)
                }
            }
            .navigationTitle("新建分组")
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
