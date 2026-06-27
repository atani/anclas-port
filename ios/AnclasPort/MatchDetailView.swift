import SwiftUI

struct MatchDetailView: View {
    let match: Match

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderBar(title: "\(match.roundLabel) \(match.competition)")

                // スコアカード
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        TeamColumn(name: match.homeTeam, isAnclas: match.homeTeam == Match.anclasName)
                        if let score = match.score {
                            Text("\(score.home) - \(score.away)")
                                .font(.system(size: 40, weight: .heavy)).monospacedDigit()
                                .frame(width: 120)
                        } else {
                            Text("VS")
                                .font(.title.weight(.heavy))
                                .foregroundStyle(Theme.orange)
                                .frame(width: 120)
                        }
                        TeamColumn(name: match.awayTeam, isAnclas: match.awayTeam == Match.anclasName)
                    }

                    if let o = match.anclasOutcome {
                        Text(Theme.outcomeLabel(o))
                            .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(Theme.outcomeColor(o), in: Capsule())
                    }

                    if let d = match.startDate {
                        Text(d.formattedJa())
                            .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }

                    if let venue = match.venue {
                        Label(venue, systemImage: "mappin.and.ellipse")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .card()

                // 得点経過
                if let goals = match.goals, !goals.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("得点経過")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.orange)

                        ForEach(goals) { goal in
                            GoalRow(goal: goal, homeTeam: match.homeTeam)
                        }
                    }
                    .card()
                }

                // 先発メンバー
                if let starters = match.starters, !starters.isEmpty {
                    LineupSection(
                        title: "先発メンバー",
                        homeTeam: match.homeTeam,
                        awayTeam: match.awayTeam,
                        players: starters
                    )
                }

                // 控え
                if let subs = match.subs, !subs.isEmpty {
                    LineupSection(
                        title: "控え",
                        homeTeam: match.homeTeam,
                        awayTeam: match.awayTeam,
                        players: subs
                    )
                }

                // 試合情報
                if let stats = match.stats {
                    StatsSection(stats: stats)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }
}

private struct TeamColumn: View {
    let name: String
    let isAnclas: Bool

    var body: some View {
        Text(name)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isAnclas ? Theme.orange : .primary)
            .frame(maxWidth: .infinity)
    }
}

private struct GoalRow: View {
    let goal: GoalEvent
    let homeTeam: String

    var body: some View {
        let isHome = goal.team == homeTeam
        HStack(spacing: 8) {
            Text(goal.minute)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            if isHome {
                goalContent
                Spacer()
            } else {
                Spacer()
                goalContent
            }
        }
        .padding(.vertical, 4)
    }

    private var goalContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "soccerball")
                .font(.caption)
                .foregroundStyle(Theme.orange)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if let num = goal.playerNumber {
                        Text("#\(num)").font(.caption2.weight(.bold))
                    }
                    Text(goal.playerName).font(.caption.weight(.semibold))
                }
                if let assist = goal.assist, !assist.isEmpty {
                    Text(assist).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Lineup

private struct LineupSection: View {
    let title: String
    let homeTeam: String
    let awayTeam: String
    let players: [MatchPlayer]

    private var homePlayers: [MatchPlayer] { players.filter { $0.team == "home" } }
    private var awayPlayers: [MatchPlayer] { players.filter { $0.team == "away" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.orange)

            HStack(alignment: .top, spacing: 12) {
                // ホーム
                VStack(alignment: .leading, spacing: 0) {
                    Text(homeTeam)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(homeTeam == Match.anclasName ? Theme.orange : .secondary)
                        .padding(.bottom, 4)
                    ForEach(homePlayers) { p in
                        PlayerRow(player: p, isAnclas: homeTeam == Match.anclasName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // アウェイ
                VStack(alignment: .leading, spacing: 0) {
                    Text(awayTeam)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(awayTeam == Match.anclasName ? Theme.orange : .secondary)
                        .padding(.bottom, 4)
                    ForEach(awayPlayers) { p in
                        PlayerRow(player: p, isAnclas: awayTeam == Match.anclasName)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }
}

private struct PlayerRow: View {
    let player: MatchPlayer
    let isAnclas: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(player.position)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22)
                .padding(.vertical, 1)
                .background(isAnclas ? Theme.orange : Color.secondary, in: RoundedRectangle(cornerRadius: 3))
            Text("#\(player.number)")
                .font(.caption2.weight(.semibold).monospacedDigit())
            Text(player.name)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Stats

private struct StatsSection: View {
    let stats: MatchStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("試合情報")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.orange)
            HStack(spacing: 16) {
                if let att = stats.attendance { statItem("👥", att) }
                if let w = stats.weather { statItem("🌤", w) }
                if let t = stats.temperature { statItem("🌡", t) }
                if let p = stats.pitch { statItem("🏟", p) }
            }
        }
        .card()
    }

    private func statItem(_ icon: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(.title3)
            Text(value).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
