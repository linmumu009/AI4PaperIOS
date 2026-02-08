import Combine
import Foundation

final class AppState: ObservableObject {
    @Published private(set) var feedPapers: [Paper] = []
    @Published private(set) var savedPapers: [Paper] = []
    @Published private(set) var isSummaryExpanded: Bool = false

    private let repository: PapersRepository
    let store: SwipeStore
    private let allPapers: [Paper]
    private var cancellables = Set<AnyCancellable>()

    init(repository: PapersRepository = .bundle, store: SwipeStore = SwipeStore()) {
        self.repository = repository
        self.store = store
        self.allPapers = repository.loadPapers()

        refreshFeed()
        refreshSavedPapers()

        store.$savedIds
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshSavedPapers()
                self?.refreshFeed()
            }
            .store(in: &cancellables)

        store.$dislikedIds
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshFeed()
            }
            .store(in: &cancellables)
    }

    var currentPaper: Paper? {
        feedPapers.first
    }

    func likeCurrent() {
        guard let paper = currentPaper else { return }
        store.save(id: paper.id)
        store.recordEvent(paperId: paper.id, action: .like)
    }

    func dislikeCurrent() {
        guard let paper = currentPaper else { return }
        store.dislike(id: paper.id)
        store.recordEvent(paperId: paper.id, action: .dislike)
    }

    func removeSaved(id: String) {
        store.removeSaved(id: id)
    }

    func linkForCurrent() -> URL? {
        currentPaper?.linkURL
    }

    private func refreshFeed() {
        let savedSet = Set(store.savedIds)
        feedPapers = allPapers.filter { paper in
            !savedSet.contains(paper.id) && !store.dislikedIds.contains(paper.id)
        }
    }

    private func refreshSavedPapers() {
        let lookup = Dictionary(uniqueKeysWithValues: allPapers.map { ($0.id, $0) })
        savedPapers = store.savedIds.compactMap { lookup[$0] }
    }
}
