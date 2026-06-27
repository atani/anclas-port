import SwiftUI

struct ContentView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
            ScheduleView()
                .tabItem { Label("日程", systemImage: "calendar") }
            StandingsView()
                .tabItem { Label("順位", systemImage: "chart.bar.fill") }
            PlayersView()
                .tabItem { Label("選手", systemImage: "person.2.fill") }
            MoreView()
                .tabItem { Label("もっと", systemImage: "ellipsis") }
        }
        .tint(Theme.orange)
    }
}
