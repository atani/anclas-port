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
                VStack(spacing: 12) {
                    HeaderBar(title: "日程・結果")

                    Picker("表示", selection: $showAll) {
                        Text("今後").tag(false)
                        Text("全試合").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if store.data == nil {
                        LoadingState(message: "日程を読み込み中…")
                    } else if anclasMatches.isEmpty {
                        EmptyState(
                            title: showAll ? "試合データがありません" : "今後の試合はありません",
                            subtitle: showAll ? nil : "「全試合」で過去の結果を見られます"
                        )
                    } else {
                        ForEach(anclasMatches) { match in
                            NavigationLink(value: match) {
                                ScheduleCard(match: match)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .navigationDestination(for: Match.self) { match in
                MatchDetailView(match: match)
            }
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
                    .foregroundStyle(Theme.orange)
                Spacer()
                if match.isFinished {
                    Text("終了").font(.caption).foregroundStyle(.secondary)
                }
            }

            if match.isFinished, let line = match.anclasScoreLine {
                HStack(spacing: 10) {
                    Text((match.anclasIsHome ? match.homeTeam : match.awayTeam).teamDisplay)
                        .font(.subheadline).foregroundStyle(Theme.orange)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Text("\(line.mine) - \(line.theirs)")
                        .font(.title2.weight(.heavy)).monospacedDigit()
                    Text(match.opponent.teamDisplay).font(.subheadline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                if let o = match.anclasOutcome {
                    Text(Theme.outcomeLabel(o))
                        .font(.caption2.weight(.heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.outcomeColor(o), in: Capsule())
                }
            } else {
                HStack(spacing: 8) {
                    Text(match.homeTeam.teamDisplay)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(match.anclasIsHome ? Theme.orange : .primary)
                    Text("vs").font(.caption).foregroundStyle(.secondary)
                    Text(match.awayTeam.teamDisplay)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(!match.anclasIsHome ? Theme.orange : .primary)
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
