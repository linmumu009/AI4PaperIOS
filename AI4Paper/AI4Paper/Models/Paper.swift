import Foundation

struct Paper: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let shortTitle: String
    let source: String
    let institution: String
    let intro: Intro?
    let keyPoints: [String]
    let analysis: [String]
    let personalView: String

    struct Intro: Codable, Hashable {
        let problem: String
        let contributions: String

        enum CodingKeys: String, CodingKey {
            case problem = "🔸研究问题"
            case contributions = "🔸主要贡献"
        }

        init(problem: String = "", contributions: String = "") {
            self.problem = problem
            self.contributions = contributions
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "paper_id"
        case title = "📖标题"
        case shortTitle = "short_title"
        case source = "🌐来源"
        case institution = "institution"
        case intro = "🛎️文章简介"
        case keyPoints = "📝重点思路"
        case analysis = "🔎分析总结"
        case personalView = "💡个人观点"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        shortTitle = try container.decodeIfPresent(String.self, forKey: .shortTitle) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        institution = try container.decodeIfPresent(String.self, forKey: .institution) ?? ""
        intro = try container.decodeIfPresent(Intro.self, forKey: .intro)
        keyPoints = try container.decodeIfPresent([String].self, forKey: .keyPoints) ?? []
        analysis = try container.decodeIfPresent([String].self, forKey: .analysis) ?? []
        personalView = try container.decodeIfPresent(String.self, forKey: .personalView) ?? ""
    }
}

extension Paper {
    var displayTitle: String {
        title.isEmpty ? shortTitle : title
    }

    var subtitle: String? {
        guard !shortTitle.isEmpty, shortTitle != title else { return nil }
        return shortTitle
    }

    var summaryText: String {
        let problem = intro?.problem ?? ""
        let contributions = intro?.contributions ?? ""
        return [problem, contributions]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var displayTags: [String] {
        [source, institution].filter { !$0.isEmpty }
    }

    /// e.g. "BMW：分离资产与攻击路径的威胁建模"
    var headerLine: String {
        switch (institution.isEmpty, shortTitle.isEmpty) {
        case (false, false): return "\(institution)：\(shortTitle)"
        case (false, true):  return institution
        case (true, false):  return shortTitle
        case (true, true):   return displayTitle
        }
    }

    /// e.g. "arxiv, 2602.05877"
    var sourceLine: String {
        [source, id].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var linkURL: URL? {
        guard !id.isEmpty else { return nil }
        guard source.lowercased() == "arxiv" else { return nil }
        return URL(string: "https://arxiv.org/abs/\(id)")
    }
}
