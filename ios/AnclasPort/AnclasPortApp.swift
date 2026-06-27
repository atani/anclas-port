import SwiftUI

@main
struct AnclasPortApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environment(store)
                .task {
                    NotificationManager.requestPermission()
                    await store.load()
                }
        }
    }
}
