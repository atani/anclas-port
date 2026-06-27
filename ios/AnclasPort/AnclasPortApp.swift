import SwiftUI

@main
struct AnclasPortApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .task { await store.load() }
        }
    }
}
