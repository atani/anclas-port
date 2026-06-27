import SwiftUI

struct HomeView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ヘッダー: オレンジ背景 + エンブレム + アプリ名
                    ZStack(alignment: .bottomTrailing) {
                        LinearGradient(
                            colors: [Theme.orange, Theme.orange.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image("Character")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 100)
                            .opacity(0.25)
                            .offset(x: 10, y: 10)
                    }
                    .frame(height: 120)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 12) {
                            Image("Emblem")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 60)
                                .shadow(radius: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("アンクラス Port")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("福岡J・アンクラス")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(.leading, 20)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

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
                            NavigationLink(value: latest) {
                                LatestResultCard(match: latest)
                            }
                            .buttonStyle(.plain)
                        }

                        if let podcast = store.data?.anclas.latestPodcast {
                            SectionLabel(podcast.isNew ? "🎙 NEW EPISODE" : "PODCAST")
                            PodcastCard(episode: podcast)
                        }

                        if let err = store.errorText {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                        }

                        if store.data == nil {
                            LoadingState()
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                }
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

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - NEXT MATCH

private struct NextMatchCard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 0) {
            // ポスターがあればカード上部に表示
            if let posterUrl = match.posterUrl, let url = URL(string: posterUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            VStack(spacing: 16) {
                if !match.roundLabel.isEmpty {
                    Text("\(match.competition) \(match.roundLabel)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Theme.orange, in: Capsule())
                }

                HStack(spacing: 12) {
                    TeamName(name: match.homeTeam, isAnclas: match.anclasIsHome)
                    Text("VS").font(.title3.weight(.heavy)).foregroundStyle(Theme.orange)
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
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }
}

private struct TeamName: View {
    let name: String
    let isAnclas: Bool
    var body: some View {
        Text(name)
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(isAnclas ? Theme.orange : .primary)
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
            .background(Theme.navy, in: Capsule())
    }
}

// MARK: - LATEST RESULT

private struct LatestResultCard: View {
    let match: Match

    var body: some View {
        VStack(spacing: 12) {
            if let line = match.anclasScoreLine {
                HStack(spacing: 14) {
                    Text("アンクラス").font(.headline).foregroundStyle(Theme.orange)
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

private struct PodcastCard: View {
    let episode: PodcastEpisode
    var body: some View {
        if let url = URL(string: episode.showUrl) {
            Link(destination: url) {
                VStack(spacing: 0) {
                    if episode.isNew {
                        // NEW: サムネイルを大きく表示
                        AsyncImage(url: URL(string: episode.thumbnailUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fit)
                            default:
                                Color(.tertiarySystemFill).frame(height: 100)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 16).padding(.top, 16)
                    }

                    HStack(spacing: 14) {
                        if !episode.isNew {
                            AsyncImage(url: URL(string: episode.thumbnailUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Color(.tertiarySystemFill)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Label("アンクラスのロッカールーム", systemImage: "headphones")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.orange)
                                if episode.isNew {
                                    Text("NEW")
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Theme.orange, in: Capsule())
                                }
                            }
                            Text(episode.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            Text("Spotify で聴く →")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct EmptyCard: View {
    let text: String
    var body: some View {
        Text(text).font(.headline).foregroundStyle(.secondary).card()
    }
}
