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
                            SectionLabel("シーズンサマリー", icon: "chart.bar.fill")
                            SeasonSummaryCard(matches: anclasMatches)
                                .padding(.horizontal, 16)

                            SectionLabel("ホーム vs アウェイ", icon: "house.fill")
                            HomeAwayCard(matches: anclasMatches)
                                .padding(.horizontal, 16)

                            SectionLabel("ゴール時間帯", icon: "clock.fill")
                            GoalTimeChart(matches: anclasMatches)
                                .padding(.horizontal, 16)

                            SectionLabel("選手別出場回数", icon: "person.3.fill")
                            AppearanceChart(
                                matches: anclasMatches,
                                rosterNames: Set((store.playersData?.players ?? []).map { $0.nameJa })
                            )
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

// MARK: - ゴール時間帯分布

private struct GoalTimeChart: View {
    let matches: [Match]

    private struct TimeBin: Identifiable {
        let label: String
        let count: Int
        var id: String { label }
    }

    // 40分ハーフ（前半0-40分、後半41-80+分）を10分刻み
    private var bins: [TimeBin] {
        var counts = [0, 0, 0, 0, 0, 0, 0, 0]
        let labels = ["1-10", "11-20", "21-30", "31-40", "41-50", "51-60", "61-70", "71-80+"]
        for m in matches {
            for g in m.goals ?? [] {
                guard g.team == Match.anclasName else { continue }
                guard let num = Int(g.minute.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)) else { continue }
                let idx = min(num <= 0 ? 0 : (num - 1) / 10, 7)
                counts[idx] += 1
            }
        }
        return zip(labels, counts).map { TimeBin(label: $0, count: $1) }
    }

    private func isSecondHalf(_ label: String) -> Bool {
        label.hasPrefix("41") || label.hasPrefix("51") || label.hasPrefix("61") || label.hasPrefix("71")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let total = bins.reduce(0) { $0 + $1.count }
            Text("\(total)ゴール")
                .font(.system(size: 28, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.orange)

            Chart(bins) { bin in
                BarMark(x: .value("時間帯", bin.label), y: .value("ゴール", bin.count))
                    .foregroundStyle(isSecondHalf(bin.label) ? Theme.orange : Theme.orange.opacity(0.6))
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
    let rosterNames: Set<String>

    private struct PlayerAppearance: Identifiable {
        let name: String
        let starters: Int
        let subs: Int
        var total: Int { starters + subs }
        var id: String { name }
    }

    private func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")
    }

    private var data: [PlayerAppearance] {
        let rosterNorm = Set(rosterNames.map { normalize($0) })
        var starterCount: [String: Int] = [:]
        var subInCount: [String: Int] = [:]
        for m in matches {
            let myTeam = m.anclasIsHome ? "home" : "away"
            var startersThisMatch = Set<String>()
            for s in m.starters ?? [] where s.team == myTeam {
                guard rosterNorm.contains(normalize(s.name)) else { continue }
                starterCount[s.name, default: 0] += 1
                startersThisMatch.insert(normalize(s.name))
            }
            // 途中出場 = substitutions で IN した選手（スタメンでない場合のみ）
            for sub in m.substitutions ?? [] where sub.team == myTeam {
                guard rosterNorm.contains(normalize(sub.inName)) else { continue }
                guard !startersThisMatch.contains(normalize(sub.inName)) else { continue }
                subInCount[sub.inName, default: 0] += 1
            }
        }
        let allNames = Set(starterCount.keys).union(subInCount.keys)
        return allNames.map {
            PlayerAppearance(name: $0, starters: starterCount[$0, default: 0], subs: subInCount[$0, default: 0])
        }
        .sorted { $0.total > $1.total }
    }

    private struct AppearanceEntry: Identifiable {
        let name: String
        let type: String
        let count: Int
        var id: String { "\(name)-\(type)" }
    }

    private var chartData: [AppearanceEntry] {
        data.flatMap { p in
            [
                AppearanceEntry(name: p.name, type: "スタメン", count: p.starters),
                AppearanceEntry(name: p.name, type: "途中出場", count: p.subs),
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(chartData) { entry in
                BarMark(x: .value("試合数", entry.count), y: .value("選手", entry.name))
                    .foregroundStyle(by: .value("種別", entry.type))
            }
            .chartForegroundStyleScale(["スタメン": Theme.orange, "途中出場": Theme.orange.opacity(0.4)])
            .chartXAxisLabel("試合数")
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: CGFloat(data.count) * 28 + 40)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Season Summary

private struct SeasonSummaryCard: View {
    let matches: [Match]

    private var stats: (wins: Int, draws: Int, losses: Int, points: Int, gf: Int, ga: Int, cleanSheets: Int, form: [Match.Outcome]) {
        var w = 0, d = 0, l = 0, gf = 0, ga = 0, cs = 0
        var form: [Match.Outcome] = []
        for m in matches {
            guard let score = m.score else { continue }
            let mine = m.anclasIsHome ? score.home : score.away
            let theirs = m.anclasIsHome ? score.away : score.home
            gf += mine; ga += theirs
            if theirs == 0 { cs += 1 }
            if mine > theirs { w += 1 } else if mine == theirs { d += 1 } else { l += 1 }
            if let o = m.anclasOutcome { form.append(o) }
        }
        return (w, d, l, w * 3 + d, gf, ga, cs, Array(form.suffix(5)))
    }

    var body: some View {
        let s = stats
        VStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(s.points)")
                    .font(.system(size: 48, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.orange)
                Text("勝点").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text("\(matches.count)試合消化").font(.caption2).foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCell(value: "\(s.wins)勝 \(s.draws)分 \(s.losses)敗", label: "戦績")
                StatCell(value: "\(s.gf) - \(s.ga)", label: "得点 - 失点")
                let gd = s.gf - s.ga
                StatCell(value: gd > 0 ? "+\(gd)" : "\(gd)", label: "得失点差",
                         valueColor: gd > 0 ? .green : gd < 0 ? .red : .secondary)
                StatCell(value: "\(s.cleanSheets)", label: "クリーンシート", valueColor: .cyan)
            }

            VStack(spacing: 6) {
                Text("直近5試合").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(Array(s.form.enumerated()), id: \.offset) { _, outcome in
                        Text(Theme.outcomeLabel(outcome))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 28)
                            .background(Theme.outcomeColor(outcome),
                                        in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatCell: View {
    let value: String
    let label: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Home vs Away

private struct HomeAwayCard: View {
    let matches: [Match]

    private struct HAStat {
        var played = 0, wins = 0, gf = 0, ga = 0
        var winRate: String { played == 0 ? "-" : "\(Int(Double(wins) / Double(played) * 100))%" }
        var avgGF: String { played == 0 ? "-" : String(format: "%.1f", Double(gf) / Double(played)) }
        var avgGA: String { played == 0 ? "-" : String(format: "%.1f", Double(ga) / Double(played)) }
    }

    private var homeAway: (home: HAStat, away: HAStat) {
        var h = HAStat(), a = HAStat()
        for m in matches {
            guard let score = m.score else { continue }
            let mine = m.anclasIsHome ? score.home : score.away
            let theirs = m.anclasIsHome ? score.away : score.home
            if m.anclasIsHome {
                h.played += 1; h.gf += mine; h.ga += theirs
                if mine > theirs { h.wins += 1 }
            } else {
                a.played += 1; a.gf += mine; a.ga += theirs
                if mine > theirs { a.wins += 1 }
            }
        }
        return (h, a)
    }

    var body: some View {
        let (h, a) = homeAway
        VStack(spacing: 14) {
            HStack {
                Label("ホーム \(h.played)試合", systemImage: "house.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.orange)
                Spacer()
                Label("アウェイ \(a.played)試合", systemImage: "airplane")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan)
            }

            CompareRow(label: "勝率", home: h.winRate, away: a.winRate,
                       homeColor: Theme.orange, awayColor: .cyan)
            CompareRow(label: "平均得点", home: h.avgGF, away: a.avgGF,
                       homeColor: Theme.orange, awayColor: .cyan)
            CompareRow(label: "平均失点", home: h.avgGA, away: a.avgGA,
                       homeColor: .red.opacity(0.8), awayColor: .red.opacity(0.8))
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CompareRow: View {
    let label: String
    let home: String
    let away: String
    var homeColor: Color = .primary
    var awayColor: Color = .primary

    var body: some View {
        HStack(spacing: 0) {
            Text(home)
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(homeColor)
                .frame(maxWidth: .infinity)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70)
            Text(away)
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(awayColor)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
