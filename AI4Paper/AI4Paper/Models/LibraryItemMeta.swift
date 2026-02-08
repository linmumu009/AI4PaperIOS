import Foundation

enum LibraryReadStatus: String, CaseIterable, Codable {
    case unread
    case reading
    case finished

    var displayName: String {
        switch self {
        case .unread: return "未读"
        case .reading: return "在读"
        case .finished: return "已读"
        }
    }
}

struct LibraryItemMeta: Codable, Hashable {
    let paperId: String
    var tags: [String]
    var folderId: String?
    var status: LibraryReadStatus
    var note: String
    var savedAt: Date
    var updatedAt: Date

    init(
        paperId: String,
        tags: [String] = [],
        folderId: String? = nil,
        status: LibraryReadStatus = .unread,
        note: String = "",
        savedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.paperId = paperId
        self.tags = tags
        self.folderId = folderId
        self.status = status
        self.note = note
        self.savedAt = savedAt
        self.updatedAt = updatedAt
    }
}
