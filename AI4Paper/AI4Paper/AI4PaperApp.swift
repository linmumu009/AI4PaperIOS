import SwiftUI

@main
struct AI4PaperApp: App {
    @StateObject private var appState: AppState
    @StateObject private var authState = AuthState()
    @StateObject private var libraryStore: LibraryStore

    init() {
        let store = LibraryStore()
        _libraryStore = StateObject(wrappedValue: store)
        _appState = StateObject(wrappedValue: AppState(libraryStore: store))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .environmentObject(authState)
                .environmentObject(libraryStore)
        }
    }
}
