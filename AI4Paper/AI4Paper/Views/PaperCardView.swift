import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    @State private var isExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(paper.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let subtitle = paper.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                TagChipsView(tags: paper.displayTags)

                VStack(alignment: .leading, spacing: 6) {
                    Text("摘要")
                        .font(.subheadline.weight(.semibold))
                    Text(paper.summaryText)
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
