import SwiftUI

struct PaperDetailView: View {
    let paper: Paper
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(paper.title)
                    .font(.title2.weight(.semibold))

                TagChipsView(tags: paper.tags)

                VStack(alignment: .leading, spacing: 6) {
                    Text("摘要")
                        .font(.headline)
                    Text(paper.summary)
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

                if !paper.authors.isEmpty || paper.year > 0 || !paper.venue.isEmpty {
                    Text(metaText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    guard let url = URL(string: paper.link) else { return }
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
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metaText: String {
        let authors = paper.authors.joined(separator: ", ")
        let year = paper.year > 0 ? String(paper.year) : ""
        let venue = paper.venue
        return [authors, year, venue]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
