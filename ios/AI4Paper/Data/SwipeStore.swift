import Foundation

final class SwipeStore: ObservableObject {
    @Published private(set) var savedIds: Set<String>
    @Published private(set) var dislikedIds: Set<String>
    @Published private(set) var events: [SwipeEvent]

    private let defaults: UserDefaults
    private let savedKey = "saved_ids"
    private let dislikedKey = "disliked_ids"
    private let eventsKey = "swipe_events"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedArray = defaults.array(forKey: savedKey) as? [String] ?? []
        let dislikedArray = defaults.array(forKey: dislikedKey) as? [String] ?? []
        self.savedIds = Set(savedArray)
        self.dislikedIds = Set(dislikedArray)

        if let data = defaults.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([SwipeEvent].self, from: data) {
            self.events = decoded
        } else {
            self.events = []
        }
    }

    func save(id: String) {
        savedIds.insert(id)
        dislikedIds.remove(id)
        persistSaved()
        persistDisliked()
    }

    func dislike(id: String) {
        dislikedIds.insert(id)
        savedIds.remove(id)
        persistSaved()
        persistDisliked()
    }

    func removeSaved(id: String) {
        savedIds.remove(id)
        persistSaved()
    }

    func recordEvent(paperId: String, action: SwipeAction) {
        let event = SwipeEvent(paperId: paperId, action: action, timestamp: Date())
        events.append(event)
        persistEvents()
    }

    private func persistSaved() {
        defaults.set(Array(savedIds), forKey: savedKey)
    }

    private func persistDisliked() {
        defaults.set(Array(dislikedIds), forKey: dislikedKey)
    }

    private func persistEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: eventsKey)
    }
}
