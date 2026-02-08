import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                LibraryView()
                    .navigationTitle("知识库")
            }
            .tabItem {
                Label("知识库", systemImage: "books.vertical")
            }

            NavigationStack {
                HomeView()
                    .navigationTitle("AI4Paper")
            }
            .tabItem {
                Label("推荐", systemImage: "sparkles")
            }
            .badge(appState.feedPapers.count)

            NavigationStack {
                ProfileView()
                    .navigationTitle("我的")
            }
            .tabItem {
                Label("我的", systemImage: "person.crop.circle")
            }
        }
    }
}
