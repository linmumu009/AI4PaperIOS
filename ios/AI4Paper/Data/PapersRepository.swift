import Foundation

struct PapersRepository {
    static let bundle = PapersRepository()

    func loadPapers() -> [Paper] {
        guard let url = Bundle.main.url(forResource: "papers", withExtension: "json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Paper].self, from: data)
        } catch {
            return []
        }
    }
}
