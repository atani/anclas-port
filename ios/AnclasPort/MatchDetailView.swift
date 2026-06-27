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
