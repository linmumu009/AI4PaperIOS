import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let phone: String
    let createdAt: Date

    init(id: String = UUID().uuidString, phone: String, createdAt: Date = Date()) {
        self.id = id
        self.phone = phone
        self.createdAt = createdAt
    }
}
