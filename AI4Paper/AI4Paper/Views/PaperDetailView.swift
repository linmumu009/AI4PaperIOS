import SwiftUI

struct PaperDetailView: View {
    let paper: Paper
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header: institution：shortTitle ──
                if !paper.institution.isEmpty || !paper.shortTitle.isEmpty {
                    Text(paper.headerLine)
                        .font(.title3.weight(.bold))
                }

                // ── 📖标题 ──
                HStack(alignment: .top, spacing: 4) {
                    Text("📖标题：")
                        .font(.body.weight(.semibold))
                    Text(paper.title)
                        .font(.body)
                }

                // ── 🌐来源 ──
                HStack(alignment: .top, spacing: 4) {
                    Text("🌐来源：")
                        .font(.body.weight(.semibold))
                    Text(paper.sourceLine)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // ── 🛎️文章简介 ──
                if let intro = paper.intro, (!intro.problem.isEmpty || !intro.contributions.isEmpty) {
                    DetailSectionHeader(title: "🛎️文章简介")

                    if !intro.problem.isEmpty {
                        DetailBulletText(label: "🔸研究问题", content: intro.problem)
                    }
                    if !intro.contributions.isEmpty {
                        DetailBulletText(label: "🔸主要贡献", content: intro.contributions)
                    }
                }

                // ── 📝重点思路 ──
                if !paper.keyPoints.isEmpty {
                    Divider()
                    DetailSectionHeader(title: "📝重点思路")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(paper.keyPoints, id: \.self) { point in
                            Text(point)
                                .font(.body)
                        }
                    }
                }

                // ── 🔎分析总结 ──
                if !paper.analysis.isEmpty {
                    Divider()
                    DetailSectionHeader(title: "🔎分析总结")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(paper.analysis, id: \.self) { point in
                            Text(point)
                                .font(.body)
                        }
                    }
                }

                // ── 💡个人观点 ──
                if !paper.personalView.isEmpty {
                    Divider()
                    DetailSectionHeader(title: "💡个人观点")
                    Text(paper.personalView)
                        .font(.body)
                }

                // ── 论文链接 ──
                if let url = paper.linkURL {
                    Divider()
                    Button {
                        openURL(url)
                    } label: {
                        Label("打开论文链接", systemImage: "arrow.up.right.square")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.15))
                            )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Detail sub‑components

private struct DetailSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
    }
}

private struct DetailBulletText: View {
    let label: String
    let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + ":")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(content)
                .font(.body)
        }
    }
}
