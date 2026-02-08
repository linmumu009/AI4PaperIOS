import Foundation

struct PapersRepository {
    static let bundle = PapersRepository()

    func loadPapers() -> [Paper] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        print("✅ ALL json in bundle:", urls.count)
        if let first = urls.first { print("✅ first json path:", first.path) }

        var papers: [Paper] = []
        let decoder = JSONDecoder()

        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let paper = try? decoder.decode(Paper.self, from: data) {
                papers.append(paper)
            } else {
                // 如果你想看哪些不是 Paper，可以临时打开这行
                // print("not a Paper:", url.lastPathComponent)
            }
        }

        print("✅ papers decoded:", papers.count)
        return papers
    }

}
