import Foundation

struct Paper: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let keyPoints: [String]
    let tags: [String]
    let authors: [String]
    let year: Int
    let venue: String
    let link: String
}
