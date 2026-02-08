import Foundation
import Combine

final class LibraryStore: ObservableObject {
    @Published private(set) var metas: [String: LibraryItemMeta]
    @Published private(set) var folders: [LibraryFolder]

    /// 当前知识库选中的文件夹，推荐页 like 时自动归入此文件夹
    @Published var activeFolderId: String?

    private let storageURL: URL

    init() {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        storageURL = baseURL.appendingPathComponent("library_store.json")
        if let snapshot = Self.loadSnapshot(from: storageURL) {
            metas = Dictionary(uniqueKeysWithValues: snapshot.metas.map { ($0.paperId, $0) })
            folders = snapshot.folders
        } else {
            metas = [:]
            folders = []
        }
    }

    // MARK: - Paper Meta

    func syncSavedIds(_ savedIds: [String]) {
        let savedSet = Set(savedIds)
        let currentSet = Set(metas.keys)
        var changed = false

        for id in savedSet.subtracting(currentSet) {
            var meta = LibraryItemMeta(paperId: id, savedAt: Date(), updatedAt: Date())
            meta.folderId = activeFolderId
            metas[id] = meta
            changed = true
        }

        for id in currentSet.subtracting(savedSet) {
            metas.removeValue(forKey: id)
            changed = true
        }

        if changed { persist() }
    }

    func meta(for paperId: String) -> LibraryItemMeta? {
        metas[paperId]
    }

    func items(for papers: [Paper]) -> [LibraryItemViewData] {
        var result: [LibraryItemViewData] = []
        result.reserveCapacity(papers.count)
        for paper in papers {
            let meta = metas[paper.id] ?? LibraryItemMeta(paperId: paper.id)
            result.append(LibraryItemViewData(paper: paper, meta: meta))
        }
        return result
    }

    func updateTags(for paperId: String, tags: [String]) {
        var meta = metas[paperId] ?? LibraryItemMeta(paperId: paperId)
        meta.tags = normalizeTags(tags)
        meta.updatedAt = Date()
        metas[paperId] = meta
        persist()
    }

    func updateStatus(for paperId: String, status: LibraryReadStatus) {
        var meta = metas[paperId] ?? LibraryItemMeta(paperId: paperId)
        meta.status = status
        meta.updatedAt = Date()
        metas[paperId] = meta
        persist()
    }

    func updateFolder(for paperId: String, folderId: String?) {
        var meta = metas[paperId] ?? LibraryItemMeta(paperId: paperId)
        meta.folderId = folderId
        meta.updatedAt = Date()
        metas[paperId] = meta
        persist()
    }

    func updateNote(for paperId: String, note: String) {
        var meta = metas[paperId] ?? LibraryItemMeta(paperId: paperId)
        meta.note = note
        meta.updatedAt = Date()
        metas[paperId] = meta
        persist()
    }

    // MARK: - Folder Hierarchy

    /// 创建文件夹，parentId 为 nil 表示顶级
    func addFolder(name: String, parentId: String? = nil) -> LibraryFolder? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 同一父级下不允许重名
        let siblings = childFolders(of: parentId)
        if let existing = siblings.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let folder = LibraryFolder(name: trimmed, parentId: parentId)
        folders.append(folder)
        persist()
        return folder
    }

    /// 递归删除文件夹及其所有子文件夹，其中论文退回上一级（parentId）
    func removeFolder(id: String) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        let parentOfRemoved = folder.parentId

        // 收集此文件夹及所有后代 id
        let descendantIds = allDescendantFolderIds(of: id)
        let idsToRemove = descendantIds.union([id])

        // 把被删文件夹中的论文退回上一级
        for (key, value) in metas where idsToRemove.contains(value.folderId ?? "") {
            var updated = value
            updated.folderId = parentOfRemoved
            updated.updatedAt = Date()
            metas[key] = updated
        }

        folders.removeAll { idsToRemove.contains($0.id) }

        if let active = activeFolderId, idsToRemove.contains(active) {
            activeFolderId = parentOfRemoved
        }

        persist()
    }

    /// 获取某个父级下的直接子文件夹（parentId == nil 表示顶级）
    func childFolders(of parentId: String?) -> [LibraryFolder] {
        folders
            .filter { $0.parentId == parentId }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 获取某文件夹下直接包含的论文数量
    func directPaperCount(in folderId: String) -> Int {
        metas.values.filter { $0.folderId == folderId }.count
    }

    /// 获取某文件夹下（含所有后代）的论文总数
    func totalPaperCount(in folderId: String) -> Int {
        let allIds = allDescendantFolderIds(of: folderId).union([folderId])
        return metas.values.filter { allIds.contains($0.folderId ?? "") }.count
    }

    /// 获取直接子文件夹数量
    func childFolderCount(of folderId: String) -> Int {
        folders.filter { $0.parentId == folderId }.count
    }

    func folderName(for id: String?) -> String? {
        guard let id else { return nil }
        return folders.first(where: { $0.id == id })?.name
    }

    /// 构建从根到某文件夹的路径（面包屑）
    func folderPath(for folderId: String) -> [LibraryFolder] {
        var path: [LibraryFolder] = []
        var currentId: String? = folderId
        while let id = currentId, let folder = folders.first(where: { $0.id == id }) {
            path.insert(folder, at: 0)
            currentId = folder.parentId
        }
        return path
    }

    /// 判断 candidateId 是否是 folderId 的后代（防止循环移动）
    func isDescendant(_ candidateId: String, of ancestorId: String) -> Bool {
        allDescendantFolderIds(of: ancestorId).contains(candidateId)
    }

    /// 获取所有文件夹的扁平列表（含缩进层级），用于选择器
    func flatFolderTree(excludingDescendantsOf excludeId: String? = nil) -> [(folder: LibraryFolder, depth: Int)] {
        var result: [(folder: LibraryFolder, depth: Int)] = []
        func walk(parentId: String?, depth: Int) {
            let children = childFolders(of: parentId)
            for child in children {
                if let excludeId, child.id == excludeId || isDescendant(child.id, of: excludeId) {
                    continue
                }
                result.append((folder: child, depth: depth))
                walk(parentId: child.id, depth: depth + 1)
            }
        }
        walk(parentId: nil, depth: 0)
        return result
    }

    // MARK: - Tags

    var allTags: [String] {
        let tags = metas.values.flatMap { $0.tags }
        return Array(Set(tags)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // MARK: - Private

    private func allDescendantFolderIds(of folderId: String) -> Set<String> {
        var result = Set<String>()
        var queue = folders.filter { $0.parentId == folderId }.map(\.id)
        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.insert(current)
            let children = folders.filter { $0.parentId == current }.map(\.id)
            queue.append(contentsOf: children)
        }
        return result
    }

    private func normalizeTags(_ tags: [String]) -> [String] {
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var result: [String] = []
        for tag in cleaned where !result.contains(tag) {
            result.append(tag)
        }
        return result
    }

    private func persist() {
        let snapshot = LibrarySnapshot(
            metas: Array(metas.values),
            folders: folders
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let url = storageURL
        DispatchQueue.global(qos: .utility).async {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func loadSnapshot(from url: URL) -> LibrarySnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LibrarySnapshot.self, from: data)
    }
}

struct LibraryItemViewData: Identifiable, Hashable {
    let paper: Paper
    let meta: LibraryItemMeta

    var id: String { paper.id }
}

private struct LibrarySnapshot: Codable {
    let metas: [LibraryItemMeta]
    let folders: [LibraryFolder]
}
