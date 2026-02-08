import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.savedPapers.isEmpty {
                EmptyLibraryView()
            } else {
                List {
                    ForEach(appState.savedPapers) { paper in
                        NavigationLink {
                            PaperDetailView(paper: paper)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(paper.displayTitle)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(paper.summaryText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("知识库")
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let id = appState.savedPapers[index].id
            appState.removeSaved(id: id)
        }
    }
}

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("暂无收藏")
                .font(.headline)
            Text("右滑即可把论文加入知识库")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
