import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            if appState.feedPapers.isEmpty {
                EmptyFeedView()
            } else {
                CardStackView(
                    papers: appState.feedPapers,
                    onLike: { _ in appState.likeCurrent() },
                    onDislike: { _ in appState.dislikeCurrent() }
                )
            }

            ActionBarView(
                isEnabled: appState.currentPaper != nil,
                onLike: { appState.likeCurrent() },
                onDislike: { appState.dislikeCurrent() }
            )
        }
        .padding()
        .navigationTitle("AI4Paper")
    }
}

private struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("没有更多论文了")
                .font(.headline)
            Text("可以去知识库查看已收藏内容")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActionBarView: View {
    let isEnabled: Bool
    let onLike: () -> Void
    let onDislike: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button(action: onLike) {
                Label("Like", systemImage: "heart.fill")
            }
            .buttonStyle(ActionButtonStyle(tint: .green))
            .disabled(!isEnabled)

            Button(action: onDislike) {
                Label("Dislike", systemImage: "xmark")
            }
            .buttonStyle(ActionButtonStyle(tint: .red))
            .disabled(!isEnabled)
        }
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(configuration.isPressed ? 0.25 : 0.18))
            )
            .foregroundStyle(tint)
    }
}
