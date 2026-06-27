import SwiftUI

struct ScheduleView: View {
    @Environment(DataStore.self) private var store
    @State private var showAll = false

    private var anclasMatches: [Match] {
        guard let matches = store.data?.matches else { return [] }
        let filtered = matches.filter { $0.isAnclas }
        if showAll { return filtered }
        return filtered.filter { $0.status == "scheduled" || ($0.startDate.map { $0.daysFromNow() >= -7 } ?? true) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Picker("表示", selection: $showAll) {
                        Text("今後").tag(false)
                        Text("全試合").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    ForEach(anclasMatches) { match in
                        ScheduleCard(match: match)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("日程・結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { await store.refresh() }
        }
    }
}

private struct ScheduleCard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(match.roundLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.blue)
                Spacer()
                if match.isFinished {
                    Text("終了").font(.caption).foregroundStyle(.secondary)
                }
            }

            if match.isFinished, let line = match.anclasScoreLine {
                HStack(spacing: 10) {
                    Text(match.anclasIsHome ? match.homeTeam : match.awayTeam)
                        .font(.subheadline).foregroundStyle(Theme.blue)
                    Text("\(line.mine) - \(line.theirs)")
                        .font(.title2.weight(.heavy)).monospacedDigit()
                    Text(match.opponent).font(.subheadline)
                        .lineLimit(1)
                }
                if let o = match.anclasOutcome {
                    Text(Theme.outcomeLabel(o))
                        .font(.caption2.weight(.heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.outcomeColor(o), in: Capsule())
                }
            } else {
                HStack(spacing: 8) {
                    Text(match.homeTeam)
                        .font(.subheadline)
                        .foregroundStyle(match.anclasIsHome ? Theme.blue : .primary)
                    Text("vs").font(.caption).foregroundStyle(.secondary)
                    Text(match.awayTeam)
                        .font(.subheadline)
                        .foregroundStyle(!match.anclasIsHome ? Theme.blue : .primary)
                }
                if let d = match.startDate {
                    Text(d.formattedJa())
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }

            if let venue = match.venue {
                Label(venue, systemImage: "mappin.and.ellipse")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .card()
        .padding(.horizontal, 16)
    }
}
