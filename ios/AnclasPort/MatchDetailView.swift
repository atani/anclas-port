import SwiftUI

struct MatchDetailView: View {
    let match: Match
    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderBar(title: "\(match.roundLabel) \(match.competition)")

                // --- スコアボード ---
                ScoreBoard(match: match)

                // --- 得点経過（左右チーム分け）---
                if let goals = match.goals, !goals.isEmpty {
                    GoalTimeline(goals: goals, homeTeam: match.homeTeam, awayTeam: match.awayTeam)
                }

                // --- 試合情報テーブル ---
                MatchInfoTable(match: match)

                // --- メンバー ---
                if let starters = match.starters, !starters.isEmpty {
                    MemberTable(
                        title: "スターティングメンバー",
                        homeTeam: match.homeTeam,
                        awayTeam: match.awayTeam,
                        homePlayers: starters.filter { $0.team == "home" },
                        awayPlayers: starters.filter { $0.team == "away" },
                        substitutions: match.substitutions ?? [],
                        store: store,
                        cards: match.cards ?? []
                    )
                }

                if let subs = match.subs, !subs.isEmpty {
                    MemberTable(
                        title: "控えメンバー",
                        homeTeam: match.homeTeam,
                        awayTeam: match.awayTeam,
                        homePlayers: subs.filter { $0.team == "home" },
                        awayPlayers: subs.filter { $0.team == "away" },
                        substitutions: match.substitutions ?? [],
                        store: store,
                        cards: match.cards ?? [],
                        isSubs: true
                    )
                }

                // マッチレポート
                if let report = match.matchReport {
                    MatchReportSection(report: report)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .navigationDestination(for: Player.self) { player in
            PlayerDetailView(player: player)
        }
    }
}

// MARK: - Score Board

private struct ScoreBoard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 12) {
            // 試合終了 / 未消化
            if match.isFinished {
                Text("試合終了")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color.secondary, in: RoundedRectangle(cornerRadius: 4))
            }

            // チーム名 + スコア
            HStack(spacing: 0) {
                // ホーム
                VStack(spacing: 4) {
                    Text(match.homeTeam)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(match.homeTeam == Match.anclasName ? Theme.orange : .primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                // スコア中央
                if let score = match.score {
                    VStack(spacing: 2) {
                        Text("\(score.home) - \(score.away)")
                            .font(.system(size: 44, weight: .heavy)).monospacedDigit()
                    }
                    .frame(width: 130)
                } else {
                    Text("VS")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(Theme.orange)
                        .frame(width: 130)
                }

                // アウェイ
                VStack(spacing: 4) {
                    Text(match.awayTeam)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(match.awayTeam == Match.anclasName ? Theme.orange : .primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            // 勝敗バッジ
            if let o = match.anclasOutcome {
                Text(Theme.outcomeLabel(o))
                    .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 6)
                    .background(Theme.outcomeColor(o), in: Capsule())
            }

            // 日時
            if let d = match.startDate {
                Text(d.formattedJa("yyyy/M/d(E) HH:mm") + " KO")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }

            // 会場
            if let venue = match.venue {
                Text(venue)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Goal Timeline (左右チーム分け)

private struct GoalTimeline: View {
    let goals: [GoalEvent]
    let homeTeam: String
    let awayTeam: String

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text(homeTeam)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(homeTeam == Match.anclasName ? Theme.orange : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("得点")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.orange)
                Text(awayTeam)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(awayTeam == Match.anclasName ? Theme.orange : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Theme.navy.opacity(0.3))

            ForEach(goals) { goal in
                let isHome = goal.team == homeTeam
                HStack(spacing: 0) {
                    // ホーム側ゴール
                    if isHome {
                        homeGoalContent(goal)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }

                    // 中央: 時間
                    Text(shortMinute(goal.minute))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.orange)
                        .frame(width: 40)

                    // アウェイ側ゴール
                    if !isHome {
                        awayGoalContent(goal)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                Divider().padding(.horizontal, 12)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func homeGoalContent(_ goal: GoalEvent) -> some View {
        HStack(spacing: 4) {
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(goal.playerName).font(.subheadline.weight(.semibold))
                if let assist = goal.assist, !assist.isEmpty {
                    Text(assist).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Image(systemName: "soccerball").font(.caption).foregroundStyle(Theme.orange)
        }
        .frame(maxWidth: .infinity)
    }

    private func awayGoalContent(_ goal: GoalEvent) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "soccerball").font(.caption).foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(goal.playerName).font(.subheadline.weight(.semibold))
                if let assist = goal.assist, !assist.isEmpty {
                    Text(assist).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func shortMinute(_ m: String) -> String {
        if let match = m.range(of: #"^\d+"#, options: .regularExpression) {
            return m[match] + "'"
        }
        return m
    }
}

// MARK: - Match Info Table

private struct MatchInfoTable: View {
    let match: Match

    var body: some View {
        let rows = buildRows()
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(rows, id: \.label) { row in
                    HStack {
                        Text(row.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Text(row.value)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    Divider().padding(.leading, 16)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private struct InfoRow {
        let label: String
        let value: String
    }

    private func buildRows() -> [InfoRow] {
        var rows: [InfoRow] = []
        if let v = match.venue { rows.append(InfoRow(label: "スタジアム", value: v)) }
        if let s = match.stats {
            if let a = s.attendance { rows.append(InfoRow(label: "入場者数", value: a)) }
            if let w = s.weather, let t = s.temperature {
                rows.append(InfoRow(label: "天候/気温", value: "\(w) / \(t)"))
            } else if let w = s.weather {
                rows.append(InfoRow(label: "天候", value: w))
            }
            if let p = s.pitch { rows.append(InfoRow(label: "ピッチ", value: p)) }
        }
        return rows
    }
}

// MARK: - Member Table (J-League style)

private struct MemberTable: View {
    let title: String
    let homeTeam: String
    let awayTeam: String
    let homePlayers: [MatchPlayer]
    let awayPlayers: [MatchPlayer]
    let substitutions: [SubstitutionEvent]
    let store: DataStore
    var cards: [CardEvent] = []
    var isSubs: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // セクションタイトル
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.navy)

            // チーム名ヘッダー
            HStack(spacing: 0) {
                Text(homeTeam)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(homeTeam == Match.anclasName ? Theme.orange : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                Text(awayTeam)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(awayTeam == Match.anclasName ? Theme.orange : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .background(Color(.tertiarySystemGroupedBackground))

            // 選手行
            let maxCount = max(homePlayers.count, awayPlayers.count)
            ForEach(0..<maxCount, id: \.self) { i in
                HStack(spacing: 0) {
                    if i < homePlayers.count {
                        let p = homePlayers[i]
                        MemberCell(
                            player: p,
                            isAnclas: homeTeam == Match.anclasName,
                            subMinute: findSubMinute(number: p.number, team: "home"),
                            isSubIn: isSubs,
                            cardType: findCard(number: p.number, team: "home"),
                            linkedPlayer: findLinkedPlayer(p, isAnclas: homeTeam == Match.anclasName)
                        )
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }

                    Divider()

                    if i < awayPlayers.count {
                        let p = awayPlayers[i]
                        MemberCell(
                            player: p,
                            isAnclas: awayTeam == Match.anclasName,
                            subMinute: findSubMinute(number: p.number, team: "away"),
                            isSubIn: isSubs,
                            cardType: findCard(number: p.number, team: "away"),
                            linkedPlayer: findLinkedPlayer(p, isAnclas: awayTeam == Match.anclasName)
                        )
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func findSubMinute(number: Int, team: String) -> String? {
        if let sub = substitutions.first(where: { $0.team == team && $0.outNumber == number }) {
            let m = sub.minute
            if let range = m.range(of: #"\d+"#, options: .regularExpression) {
                return String(m[range]) + "'"
            }
            return m
        }
        if let sub = substitutions.first(where: { $0.team == team && $0.inNumber == number }) {
            let m = sub.minute
            if let range = m.range(of: #"\d+"#, options: .regularExpression) {
                return String(m[range]) + "'"
            }
            return m
        }
        return nil
    }

    private func findLinkedPlayer(_ mp: MatchPlayer, isAnclas: Bool) -> Player? {
        guard isAnclas else { return nil }
        return store.playersData?.players.first { $0.number == mp.number }
    }

    /// 該当選手のカード種別（赤優先）。無ければ nil
    private func findCard(number: Int, team: String) -> String? {
        let matched = cards.filter { $0.team == team && $0.number == number }
        if matched.contains(where: { $0.type == "red" }) { return "red" }
        return matched.first?.type
    }
}

private struct MemberCell: View {
    let player: MatchPlayer
    let isAnclas: Bool
    var subMinute: String? = nil
    var isSubIn: Bool = false
    var cardType: String? = nil
    var linkedPlayer: Player? = nil

    var body: some View {
        Group {
            if let linked = linkedPlayer {
                NavigationLink(value: linked) { cellContent }
            } else {
                cellContent
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var cellContent: some View {
        HStack(spacing: 4) {
            Text(player.position)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 22, height: 18)
                .background(isAnclas ? Theme.orange : Color.gray, in: RoundedRectangle(cornerRadius: 3))

            Text("\(player.number)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 24, alignment: .trailing)

            Text(player.name)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // カード（警告=黄 / 退場=赤）
            if let cardType {
                RoundedRectangle(cornerRadius: 2)
                    .fill(cardType == "red" ? Color.red : Color.yellow)
                    .frame(width: 9, height: 13)
            }

            Spacer(minLength: 2)

            if let min = subMinute {
                HStack(spacing: 2) {
                    Text(min)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    // 控えからIN = 右斜め上（緑）、先発のOUT = 右斜め下（赤）
                    Image(systemName: isSubIn ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundStyle(isSubIn ? .green : .red)
                }
            }

            if linkedPlayer != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.quaternary)
            }
        }
    }
}

// MARK: - Match Report

private struct MatchReportSection: View {
    let report: MatchReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("マッチレポート")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.orange)

            Text(report.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if let coach = report.coachComment {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Theme.orange)
                        Text("監督 \(coach.name)")
                            .font(.subheadline.weight(.bold))
                    }
                    Text(coach.comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Theme.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            ForEach(report.playerComments) { pc in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if let num = pc.number {
                            Text("#\(num)").font(.caption.weight(.bold)).foregroundStyle(Theme.orange)
                        }
                        Text(pc.name).font(.subheadline.weight(.bold))
                    }
                    Text(pc.comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .card()
    }
}
