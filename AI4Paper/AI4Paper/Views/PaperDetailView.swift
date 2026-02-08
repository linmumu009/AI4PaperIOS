import SwiftUI

struct PaperDetailView: View {
    let paper: Paper
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(paper.displayTitle)
                    .font(.title2.weight(.semibold))

                if let subtitle = paper.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TagChipsView(tags: paper.displayTags)

                VStack(alignment: .leading, spacing: 6) {
                    Text("摘要")
                        .font(.headline)
                    Text(paper.summaryText)
                        .font(.body)
                }

                if !paper.keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key points")
                            .font(.headline)
                        ForEach(paper.keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(point)
                            }
                            .font(.subheadline)
                        }
                    }
                }

                if !paper.analysis.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("分析总结")
                            .font(.headline)
                        ForEach(paper.analysis, id: \.self) { point in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                Text(point)
                            }
                            .font(.subheadline)
                        }
                    }
                }

                if !paper.personalView.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("个人观点")
                            .font(.headline)
                        Text(paper.personalView)
                            .font(.body)
                    }
                }

                if let url = paper.linkURL {
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
