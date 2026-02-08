import Foundation

enum SwipeAction: String, Codable {
    case like
    case dislike
}

struct SwipeEvent: Codable, Hashable {
    let paperId: String
    let action: SwipeAction
    let timestamp: Date
}
