import Foundation

struct PapersRepository {
    static let bundle = PapersRepository()

    func loadPapers() -> [Paper] {
        guard let baseURL = SummaryLimitConfig.baseURL else { return [] }
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: nil) else {
            return []
        }

        var papers: [Paper] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "json" else { continue }
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            guard let paper = try? JSONDecoder().decode(Paper.self, from: data) else { continue }
            papers.append(paper)
        }

        return papers.sorted { $0.id < $1.id }
    }
}

private enum SummaryLimitConfig {
    static var baseURL: URL? {
        let env = ProcessInfo.processInfo.environment
        let path = env["SUMMARY_LIMIT_PATH"] ?? "input/summary_limit/json"
        return URL(fileURLWithPath: path)
    }
}
