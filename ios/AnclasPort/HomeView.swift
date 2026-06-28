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

                    // 2026シーズンスローガン
                    SloganBanner()
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

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

                        if let video = store.data?.anclas.latestYouTube {
                            SectionLabel(video.isNew ? "📺 NEW VIDEO" : "YOUTUBE")
                            YouTubeCard(video: video)
                        }

                        if let items = store.data?.anclas.shopItems, !items.isEmpty {
                            SectionLabel("🛒 公式オンラインショップ")
                            ShopCarouselCard(items: items)
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
        Text(name.teamDisplay)
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
                    Text(match.opponent.teamDisplay).font(.headline)
                        .lineLimit(3).multilineTextAlignment(.center)
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

// MARK: - Slogan Banner

/// 2026 シーズンスローガン
private struct SloganBanner: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("2026 SEASON SLOGAN")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(Theme.orange)
            }
            Text("RISE again")
                .font(.system(size: 28, weight: .heavy, design: .serif))
                .italic()
                .foregroundStyle(Theme.navy)
            Text("もう一度、ともに。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Theme.orange.opacity(0.08),
                    Theme.orange.opacity(0.02),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - YouTube

private struct YouTubeCard: View {
    let video: YouTubeVideo

    /// ショート動画判定（ID が "shorts/" を含むか、サムネが縦長を示すか）
    /// YouTube は通常 hqdefault.jpg=480x360（4:3）を返すが、実画像のサイズで判定する
    var body: some View {
        if let url = URL(string: video.url) {
            Link(destination: url) {
                VStack(spacing: 0) {
                    ZStack(alignment: .center) {
                        // 16:9 でフィット表示（ショート=縦長は letterbox、通常=横長はfill寄り）
                        AsyncImage(url: URL(string: video.thumbnailUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fit)
                            default:
                                Color(.tertiarySystemFill)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.black)

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16).padding(.top, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Label("公式チャンネル", systemImage: "play.rectangle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.orange)
                            if video.isNew {
                                Text("NEW")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.orange, in: Capsule())
                            }
                        }
                        Text(video.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("YouTube で見る →")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Shop Carousel

/// 公式オンラインショップ商品を3秒ごとにフェードで切り替える自動カルーセル
private struct ShopCarouselCard: View {
    let items: [ShopItem]
    @State private var index: Int = 0

    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let item = items[index % items.count]
        Link(destination: URL(string: item.url)!) {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string: item.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.tertiarySystemFill)
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(item.price)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Theme.orange)
                    HStack(spacing: 4) {
                        Text("BASE で購入 →")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(index % items.count + 1) / \(items.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .id(item.id) // フェード再生用
            .transition(.opacity)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.4), value: index)
        .onReceive(timer) { _ in
            index = (index + 1) % items.count
        }
    }
}
