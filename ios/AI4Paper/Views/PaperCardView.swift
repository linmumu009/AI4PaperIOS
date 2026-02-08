import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    @State private var isExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(paper.title)
                    .font(.headline)
                    .lineLimit(2)

                TagChipsView(tags: paper.tags)

                VStack(alignment: .leading, spacing: 6) {
                    Text("摘要")
                        .font(.subheadline.weight(.semibold))
                    Text(paper.summary)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 6)

                    Button(isExpanded ? "收起" : "展开") {
                        isExpanded.toggle()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }

                if !paper.keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key points")
                            .font(.subheadline.weight(.semibold))
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
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
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
