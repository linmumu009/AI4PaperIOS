import Foundation

struct LibraryFolder: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var parentId: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        parentId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = createdAt
    }
}
