import SwiftUI

@main
struct AnclasPortApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem { Label("ホーム", systemImage: "house.fill") }
                ScheduleView()
                    .tabItem { Label("日程", systemImage: "calendar") }
                StandingsView()
                    .tabItem { Label("順位", systemImage: "chart.bar.fill") }
                PlayersView()
                    .tabItem { Label("選手", systemImage: "person.2.fill") }
            }
            .tint(Theme.blue)
            .environment(store)
            .task { await store.load() }
        }
    }
}
