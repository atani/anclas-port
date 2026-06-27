import SwiftUI

/// ホーム（起動直後）。最重要の「次の試合」「直近結果」を最上部に大きく出す（UX原則1）。
struct HomeView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let next = store.data?.anclas.nextMatch {
                        SectionLabel("NEXT MATCH")
                        NextMatchCard(match: next)
                    } else if store.data != nil {
                        SectionLabel("NEXT MATCH")
                        EmptyCard(text: "次節調整中")
                    }

                    if let latest = store.data?.anclas.latestResult {
                        SectionLabel("LATEST RESULT")
                        LatestResultCard(match: latest)
                    }

                    if let err = store.errorText {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if store.data == nil {
                        ProgressView("読み込み中…")
                            .padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("福岡J・アンクラス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { await store.refresh() }
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - NEXT MATCH

private struct NextMatchCard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 16) {
            if !match.roundLabel.isEmpty {
                Text("\(match.competition) \(match.roundLabel)")
                    .font(.headline)
                    .foregroundStyle(Theme.navy)
            }

            HStack(spacing: 12) {
                TeamName(name: match.homeTeam, isAnclas: match.anclasIsHome)
                Text("VS").font(.title3.weight(.heavy)).foregroundStyle(.secondary)
                TeamName(name: match.awayTeam, isAnclas: !match.anclasIsHome)
            }

            if let d = match.startDate {
                Text(d.formattedJa() + " KO")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                CountdownBadge(days: d.daysFromNow())
            }

            if let venue = match.venue {
                Label(venue, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

private struct TeamName: View {
    let name: String
    let isAnclas: Bool
    var body: some View {
        Text(name)
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(isAnclas ? Theme.blue : .primary)
            .frame(maxWidth: .infinity)
    }
}

private struct CountdownBadge: View {
    let days: Int
    var body: some View {
        let label = days <= 0 ? "本日キックオフ" : "あと \(days) 日"
        return Text("⏱ " + label)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Theme.blue, in: Capsule())
    }
}

// MARK: - LATEST RESULT

private struct LatestResultCard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 12) {
            if let line = match.anclasScoreLine {
                HStack(spacing: 14) {
                    Text("アンクラス").font(.headline).foregroundStyle(Theme.blue)
                    Text("\(line.mine) - \(line.theirs)")
                        .font(.system(size: 34, weight: .heavy)).monospacedDigit()
                    Text(match.opponent).font(.headline)
                        .lineLimit(2).multilineTextAlignment(.center)
                }
            }
            HStack {
                if let o = match.anclasOutcome {
                    Text(Theme.outcomeLabel(o))
                        .font(.caption.weight(.heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Theme.outcomeColor(o), in: Capsule())
                }
                if let venue = match.venue {
                    Label(venue, systemImage: "mappin.and.ellipse")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let d = match.startDate {
                    Text("\(d.formattedJa("M/d")) \(match.roundLabel)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }
}

private struct EmptyCard: View {
    let text: String
    var body: some View {
        Text(text).font(.headline).foregroundStyle(.secondary).card()
    }
}
