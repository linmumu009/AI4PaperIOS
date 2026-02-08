import Foundation

struct SessionToken: Codable, Equatable {
    let token: String
    let createdAt: Date

    init(token: String = UUID().uuidString, createdAt: Date = Date()) {
        self.token = token
        self.createdAt = createdAt
    }
}
