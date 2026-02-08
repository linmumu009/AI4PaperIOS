import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var metas: [String: LibraryItemMeta]
    @Published private(set) var folders: [LibraryFolder]

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

    func syncSavedIds(_ savedIds: [String]) {
        let savedSet = Set(savedIds)
        let currentSet = Set(metas.keys)
        var changed = false

        for id in savedSet.subtracting(currentSet) {
            metas[id] = LibraryItemMeta(paperId: id, savedAt: Date(), updatedAt: Date())
            changed = true
        }

        for id in currentSet.subtracting(savedSet) {
            metas.removeValue(forKey: id)
            changed = true
        }

        if changed {
            persist()
        }
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

    func addFolder(name: String) -> LibraryFolder? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = folders.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let folder = LibraryFolder(name: trimmed)
        folders.append(folder)
        folders.sort { $0.createdAt < $1.createdAt }
        persist()
        return folder
    }

    func removeFolder(id: String) {
        folders.removeAll { $0.id == id }
        for (key, value) in metas where value.folderId == id {
            var updated = value
            updated.folderId = nil
            updated.updatedAt = Date()
            metas[key] = updated
        }
        persist()
    }

    func folderName(for id: String?) -> String? {
        guard let id else { return nil }
        return folders.first(where: { $0.id == id })?.name
    }

    var allTags: [String] {
        let tags = metas.values.flatMap { $0.tags }
        return Array(Set(tags)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
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
        try? data.write(to: storageURL, options: .atomic)
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
