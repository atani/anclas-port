import SwiftUI
import Charts

struct StandingsView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderBar(title: "順位表")

                if let data = store.standingsData {
                    VStack(spacing: 0) {
                        ColumnHeader()
                        ForEach(Array(data.table.enumerated()), id: \.element.id) { idx, row in
                            StandingRowView(row: row, isLast: idx == data.table.count - 1)
                        }
                    }
                    .anclasCard(padding: 0)
                    .padding(.horizontal, 16)

                    Text("\(data.competition)　\(data.season)シーズン")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)

                    if let scorers = data.scorers, !scorers.isEmpty {
                        SectionLabel("得点ランキング", icon: "soccerball")
                        VStack(spacing: 0) {
                            ForEach(Array(scorers.enumerated()), id: \.element.id) { idx, scorer in
                                ScorerRowView(scorer: scorer, isLast: idx == scorers.count - 1)
                            }
                        }
                        .anclasCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    if let assists = data.assists, !assists.isEmpty {
                        SectionLabel("アシストランキング", icon: "arrow.turn.up.right")
                        VStack(spacing: 0) {
                            ForEach(Array(assists.enumerated()), id: \.element.id) { idx, assist in
                                AssistRowView(assist: assist, isLast: idx == assists.count - 1)
                            }
                        }
                        .anclasCard(padding: 0)
                        .padding(.horizontal, 16)
                    }

                    // グラフセクション
                    if let matches = store.matchesData?.matches {
                        let anclasMatches = matches.filter { $0.isAnclas && $0.isFinished && $0.score != nil }
                        if !anclasMatches.isEmpty {
                            SectionLabel("勝点推移", icon: "chart.line.uptrend.xyaxis")
                            PointsProgressChart(matches: anclasMatches)
                                .padding(.horizontal, 16)

                            SectionLabel("ゴール時間帯", icon: "clock.fill")
                            GoalTimeChart(matches: anclasMatches)
                                .padding(.horizontal, 16)

                            SectionLabel("選手別出場回数", icon: "person.3.fill")
                            AppearanceChart(matches: anclasMatches)
                                .padding(.horizontal, 16)
                        }
                    }
                } else {
                    LoadingState(message: "順位表を読み込み中…")
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await store.refresh() }
    }
}

private struct ColumnHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("順").frame(width: 28)
            Text("チーム").frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text("試"); Text("勝"); Text("分"); Text("敗")
            }
            .frame(width: 22)
            Group {
                Text("得"); Text("失"); Text("差")
            }
            .frame(width: 24)
            Text("点").frame(width: 30)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Theme.navy.opacity(0.06))
    }
}

private struct StandingRowView: View {
    let row: StandingRow
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                RankBadge(rank: row.rank, isAnclas: row.isAnclas)
                    .frame(width: 28)

                Text(row.team.teamDisplay)
                    .font(.caption.weight(row.isAnclas ? .bold : .regular))
                    .foregroundStyle(row.isAnclas ? Theme.orange : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    Text("\(row.played)").foregroundStyle(.secondary)
                    Text("\(row.win)")
                    Text("\(row.draw)")
                    Text("\(row.loss)")
                }
                .font(.caption.monospacedDigit())
                .frame(width: 22)

                Group {
                    Text("\(row.gf)")
                    Text("\(row.ga)")
                    Text(row.gd > 0 ? "+\(row.gd)" : "\(row.gd)")
                        .foregroundStyle(row.gd > 0 ? .green : row.gd < 0 ? .red : .secondary)
                }
                .font(.caption.monospacedDigit())
                .frame(width: 24)

                Text("\(row.points)")
                    .font(.callout.weight(.heavy).monospacedDigit())
                    .foregroundStyle(row.isAnclas ? Theme.orange : .primary)
                    .frame(width: 30)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .background(row.isAnclas ? Theme.orange.opacity(0.10) : Color.clear)
            .overlay(alignment: .leading) {
                if row.isAnclas {
                    Rectangle().fill(Theme.orange).frame(width: 4)
                }
            }

            if !isLast {
                Divider().padding(.leading, 14)
            }
        }
    }
}

private struct ScorerRowView: View {
    let scorer: ScorerRank
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                RankBadge(rank: scorer.rank, isAnclas: false)
                    .frame(width: 36)

                HStack(spacing: 6) {
                    if let number = scorer.number {
                        Text("#\(number)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(scorer.name)
                        .font(.callout)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let lr = scorer.leagueRank {
                        Text("リーグ\(lr)位")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(scorer.goals)")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Theme.orange)
                    Text("点")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if !isLast {
                Divider().padding(.leading, 14)
            }
        }
    }
}

private struct AssistRowView: View {
    let assist: AssistRank
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                RankBadge(rank: assist.rank, isAnclas: false)
                    .frame(width: 36)

                HStack(spacing: 6) {
                    if let number = assist.number {
                        Text("#\(number)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(assist.name)
                        .font(.callout)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(assist.assists)")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Theme.orange)
                    Text("A")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if !isLast {
                Divider().padding(.leading, 14)
            }
        }
    }
}

private struct RankBadge: View {
    let rank: Int
    let isAnclas: Bool

    private var color: Color {
        switch rank {
        case 1: return Theme.orange
        case 2: return Color(.systemGray)
        case 3: return Theme.yellow
        default: return Color(.systemGray3)
        }
    }

    var body: some View {
        Text("\(rank)")
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(rank <= 3 ? .white : .secondary)
            .frame(width: 26, height: 26)
            .background(rank <= 3 ? color : Color.clear, in: Circle())
    }
}

// MARK: - 勝点推移グラフ

private struct PointsProgressChart: View {
    let matches: [Match]

    private var data: [(round: Int, points: Int)] {
        var pts = 0
        return matches.compactMap { m in
            guard let score = m.score, let round = m.round else { return nil }
            let mine = m.anclasIsHome ? score.home : score.away
            let theirs = m.anclasIsHome ? score.away : score.home
            if mine > theirs { pts += 3 }
            else if mine == theirs { pts += 1 }
            return (round, pts)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let last = data.last {
                Text("\(last.points)pt")
                    .font(.system(size: 32, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.orange)
                + Text(" / \(data.count)試合")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Chart(data, id: \.round) { item in
                LineMark(x: .value("節", item.round), y: .value("勝点", item.points))
                    .foregroundStyle(Theme.orange)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("節", item.round), y: .value("勝点", item.points))
                    .foregroundStyle(Theme.orange.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("節", item.round), y: .value("勝点", item.points))
                    .foregroundStyle(Theme.orange)
                    .symbolSize(30)
            }
            .chartXAxisLabel("節")
            .chartYAxisLabel("勝点")
            .frame(height: 180)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ゴール時間帯分布

private struct GoalTimeChart: View {
    let matches: [Match]

    private struct TimeBin: Identifiable {
        let label: String
        let count: Int
        var id: String { label }
    }

    private var bins: [TimeBin] {
        var counts = [0, 0, 0, 0, 0, 0]
        let labels = ["0-15", "16-30", "31-45", "46-60", "61-75", "76-90+"]
        for m in matches {
            for g in m.goals ?? [] {
                guard g.team == Match.anclasName else { continue }
                guard let num = Int(g.minute.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) else { continue }
                let idx = min(num <= 0 ? 0 : (num - 1) / 15, 5)
                counts[idx] += 1
            }
        }
        return zip(labels, counts).map { TimeBin(label: $0, count: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let total = bins.reduce(0) { $0 + $1.count }
            Text("\(total)ゴール")
                .font(.system(size: 28, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.orange)

            Chart(bins) { bin in
                BarMark(x: .value("時間帯", bin.label), y: .value("ゴール", bin.count))
                    .foregroundStyle(
                        bin.label.hasPrefix("46") || bin.label.hasPrefix("61") || bin.label.hasPrefix("76")
                            ? Theme.orange : Theme.orange.opacity(0.6)
                    )
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if bin.count > 0 {
                            Text("\(bin.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
            }
            .chartXAxisLabel("分")
            .frame(height: 160)

            HStack(spacing: 4) {
                Circle().fill(Theme.orange.opacity(0.6)).frame(width: 8, height: 8)
                Text("前半").font(.caption2).foregroundStyle(.secondary)
                Circle().fill(Theme.orange).frame(width: 8, height: 8)
                Text("後半").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - 選手別出場回数

private struct AppearanceChart: View {
    let matches: [Match]

    private struct PlayerAppearance: Identifiable {
        let name: String
        let starters: Int
        let subs: Int
        var total: Int { starters + subs }
        var id: String { name }
    }

    private var data: [PlayerAppearance] {
        var starterCount: [String: Int] = [:]
        var subCount: [String: Int] = [:]
        for m in matches {
            let myTeam = m.anclasIsHome ? "home" : "away"
            for s in m.starters ?? [] where s.team == myTeam {
                starterCount[s.name, default: 0] += 1
            }
            for s in m.subs ?? [] where s.team == myTeam {
                subCount[s.name, default: 0] += 1
            }
        }
        let allNames = Set(starterCount.keys).union(subCount.keys)
        return allNames.map {
            PlayerAppearance(name: $0, starters: starterCount[$0, default: 0], subs: subCount[$0, default: 0])
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(data) { player in
                BarMark(x: .value("スタメン", player.starters), y: .value("選手", player.name))
                    .foregroundStyle(Theme.orange)
                BarMark(x: .value("控え", player.subs), y: .value("選手", player.name))
                    .foregroundStyle(Theme.orange.opacity(0.4))
            }
            .chartXAxisLabel("試合数")
            .frame(height: CGFloat(data.count) * 28 + 40)

            HStack(spacing: 4) {
                Circle().fill(Theme.orange).frame(width: 8, height: 8)
                Text("スタメン").font(.caption2).foregroundStyle(.secondary)
                Circle().fill(Theme.orange.opacity(0.4)).frame(width: 8, height: 8)
                Text("途中出場").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
