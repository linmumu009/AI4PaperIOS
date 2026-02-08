import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    @State private var isExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // ── Header: institution：shortTitle ──
                if !paper.institution.isEmpty || !paper.shortTitle.isEmpty {
                    Text(paper.headerLine)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                }

                // ── 📖标题 ──
                HStack(alignment: .top, spacing: 4) {
                    Text("📖标题：")
                        .font(.subheadline.weight(.semibold))
                    Text(paper.title)
                        .font(.subheadline)
                }

                // ── 🌐来源 ──
                HStack(alignment: .top, spacing: 4) {
                    Text("🌐来源：")
                        .font(.subheadline.weight(.semibold))
                    Text(paper.sourceLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // ── 🛎️文章简介 ──
                if let intro = paper.intro, (!intro.problem.isEmpty || !intro.contributions.isEmpty) {
                    SectionHeader(title: "🛎️文章简介")

                    if !intro.problem.isEmpty {
                        BulletText(label: "🔸研究问题", content: intro.problem)
                    }
                    if !intro.contributions.isEmpty {
                        BulletText(label: "🔸主要贡献", content: intro.contributions)
                    }
                }

                // ── 📝重点思路 ──
                if !paper.keyPoints.isEmpty {
                    Divider()
                    SectionHeader(title: "📝重点思路")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(paper.keyPoints, id: \.self) { point in
                            Text(point)
                                .font(.subheadline)
                                .lineLimit(isExpanded ? nil : 3)
                        }
                    }
                }

                // ── 🔎分析总结 ──
                if !paper.analysis.isEmpty {
                    Divider()
                    SectionHeader(title: "🔎分析总结")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(paper.analysis, id: \.self) { point in
                            Text(point)
                                .font(.subheadline)
                                .lineLimit(isExpanded ? nil : 3)
                        }
                    }
                }

                // ── 💡个人观点 ──
                if !paper.personalView.isEmpty {
                    Divider()
                    SectionHeader(title: "💡个人观点")
                    Text(paper.personalView)
                        .font(.subheadline)
                        .lineLimit(isExpanded ? nil : 4)
                }

                // ── 展开/收起 ──
                Button(isExpanded ? "收起" : "展开全部") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
    }
}

// MARK: - Sub‑components

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
    }
}

private struct BulletText: View {
    let label: String
    let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label + ":")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(content)
                .font(.subheadline)
        }
    }
}
