import SwiftUI

struct MatchDetailView: View {
    let match: Match

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderBar(title: "\(match.roundLabel) \(match.competition)")

                // スコアカード + 試合情報を統合
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

                    // 試合情報をスコアカード内に統合
                    if let stats = match.stats {
                        Divider()
                        HStack(spacing: 16) {
                            if let att = stats.attendance {
                                Label(att, systemImage: "person.2.fill").font(.caption)
                            }
                            if let w = stats.weather {
                                Label(w, systemImage: "cloud.fill").font(.caption)
                            }
                            if let t = stats.temperature {
                                Label(t, systemImage: "thermometer.medium").font(.caption)
                            }
                            if let p = stats.pitch {
                                Label(p, systemImage: "sportscourt.fill").font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
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

                // 選手交代
                if let subs = match.substitutions, !subs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("選手交代")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.orange)
                        ForEach(subs) { sub in
                            SubstitutionRow(sub: sub, homeTeam: match.homeTeam)
                        }
                    }
                    .card()
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
        .navigationDestination(for: Player.self) { player in
            PlayerDetailView(player: player)
        }
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
    @Environment(DataStore.self) private var store

    private var homePlayers: [MatchPlayer] { players.filter { $0.team == "home" } }
    private var awayPlayers: [MatchPlayer] { players.filter { $0.team == "away" } }

    private func findPlayer(_ mp: MatchPlayer, isAnclas: Bool) -> Player? {
        guard isAnclas else { return nil }
        return store.playersData?.players.first { $0.number == mp.number }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.orange)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(homeTeam)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(homeTeam == Match.anclasName ? Theme.orange : .secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                    ForEach(homePlayers) { p in
                        let linked = findPlayer(p, isAnclas: homeTeam == Match.anclasName)
                        PlayerRow(player: p, isAnclas: homeTeam == Match.anclasName, linkedPlayer: linked)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    Text(awayTeam)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(awayTeam == Match.anclasName ? Theme.orange : .secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 4)
                    ForEach(awayPlayers) { p in
                        let linked = findPlayer(p, isAnclas: awayTeam == Match.anclasName)
                        PlayerRow(player: p, isAnclas: awayTeam == Match.anclasName, linkedPlayer: linked)
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
    var linkedPlayer: Player? = nil

    var body: some View {
        Group {
            if let linked = linkedPlayer {
                NavigationLink(value: linked) { content }
            } else {
                content
            }
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        HStack(spacing: 4) {
            Text(player.position)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24)
                .padding(.vertical, 2)
                .background(isAnclas ? Theme.orange : Color.secondary, in: RoundedRectangle(cornerRadius: 4))
            Text("#\(player.number)")
                .font(.caption.weight(.semibold).monospacedDigit())
            Text(player.name)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if linkedPlayer != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Substitutions

private struct SubstitutionRow: View {
    let sub: SubstitutionEvent
    let homeTeam: String

    var body: some View {
        HStack(spacing: 8) {
            Text(sub.minute)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(.red).font(.caption)
                    Text("#\(sub.outNumber) \(sub.outName)").font(.caption)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill").foregroundStyle(.green).font(.caption)
                    Text("#\(sub.inNumber) \(sub.inName)").font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
