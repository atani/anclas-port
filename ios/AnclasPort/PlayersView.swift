import SwiftUI

struct PlayersView: View {
    @Environment(DataStore.self) private var store

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HeaderBar(title: "選手名鑑")

                    if let players = store.playersData?.players {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(players) { player in
                                NavigationLink(value: player) {
                                    PlayerCell(player: player)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                    } else {
                        LoadingState(message: "選手名鑑を読み込み中…")
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .navigationDestination(for: Player.self) { player in
                PlayerDetailView(player: player)
            }
            .refreshable { await store.refresh() }
        }
    }
}

private struct PlayerCell: View {
    let player: Player

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: player.photo.medium ?? player.photo.full ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color(.tertiarySystemFill)
                        .overlay { Image(systemName: "person.fill").font(.largeTitle).foregroundStyle(.quaternary) }
                }
            }
            .frame(height: 160)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(player.displayNumber)
                .font(.title2.weight(.heavy)).monospacedDigit()
                .foregroundStyle(Theme.orange)
            Text(player.nameJa)
                .font(.subheadline.weight(.semibold))
            if let nick = player.nickname, !nick.isEmpty {
                Text(nick)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - 選手詳細

struct PlayerDetailView: View {
    let player: Player
    @Environment(DataStore.self) private var store

    private var allPlayers: [Player] { store.playersData?.players ?? [] }
    private var currentIndex: Int? { allPlayers.firstIndex(where: { $0.id == player.id }) }
    private var prevPlayer: Player? {
        guard let i = currentIndex, i > 0 else { return nil }
        return allPlayers[i - 1]
    }
    private var nextPlayer: Player? {
        guard let i = currentIndex, i < allPlayers.count - 1 else { return nil }
        return allPlayers[i + 1]
    }

    /// 該当選手の得点ランキング情報。背番号で照合（無ければ名前で）
    private var scorerRank: ScorerRank? {
        guard let list = store.standingsData?.scorers else { return nil }
        if let n = player.number, let r = list.first(where: { $0.number == n }) { return r }
        return list.first(where: { $0.name.replacingOccurrences(of: " ", with: "") == player.nameJa.replacingOccurrences(of: " ", with: "") })
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ヘッダー + 戻るボタン統合
                ZStack(alignment: .topLeading) {
                    HeaderBar(title: "\(player.displayNumber) \(player.nameJa)")
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.3), in: Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 8)
                }

                // 写真: fit で頭が切れないように
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: player.photo.large ?? player.photo.full ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        default:
                            Color(.tertiarySystemFill).frame(height: 300)
                        }
                    }

                    LinearGradient(
                        colors: [.clear, Theme.navy.opacity(0.8), Theme.navy.opacity(0.95)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 120)

                    HStack(alignment: .bottom, spacing: 12) {
                        Text(player.displayNumber)
                            .font(.system(size: 50, weight: .heavy)).monospacedDigit()
                            .foregroundStyle(Theme.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            if let pos = player.position {
                                Text(pos)
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(Theme.orange)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(.white.opacity(0.2), in: Capsule())
                            }
                            Text(player.nameJa)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            if let en = player.nameEn {
                                Text(en).font(.caption).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        Spacer()
                        if let rank = scorerRank {
                            GoalBadge(scorer: rank)
                        }
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 12)

                if hasProfile {
                    ProfileSection(player: player)
                }

                if !player.personal.isEmpty {
                    PersonalSection(items: player.personal)
                }

                if let blogs = player.blogPosts, !blogs.isEmpty {
                    BlogSection(posts: blogs)
                }

                // 前後の選手への回遊ナビ
                PlayerNavigation(prev: prevPlayer, next: nextPlayer)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarHidden(true)
    }

    private var hasProfile: Bool {
        [player.profile.birthdate, player.profile.hometown, player.profile.height, player.profile.career]
            .contains(where: { $0 != nil })
    }
}

private struct PlayerNavigation: View {
    let prev: Player?
    let next: Player?

    var body: some View {
        HStack {
            if let p = prev {
                NavigationLink(value: p) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.displayNumber).font(.caption2.weight(.bold))
                            Text(p.nameJa).font(.caption).lineLimit(1)
                        }
                    }
                    .foregroundStyle(Theme.orange)
                }
            }
            Spacer()
            if let n = next {
                NavigationLink(value: n) {
                    HStack(spacing: 6) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(n.displayNumber).font(.caption2.weight(.bold))
                            Text(n.nameJa).font(.caption).lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(Theme.orange)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProfileSection: View {
    let player: Player
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROFILE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Group {
                row("生年月日", player.profile.birthdate)
                row("出身", player.profile.hometown)
                row("身長", player.profile.height)
                row("血液型", player.profile.bloodType)
            }
            if let career = player.profile.career {
                Text("経歴").font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.top, 4)
                Text(career.replacingOccurrences(of: " – ", with: "\n→ "))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        if let v = value {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                Text(v).font(.subheadline)
            }
        }
    }
}

private struct PersonalSection: View {
    let items: [PersonalItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERSONAL").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(items, id: \.label) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.label).font(.caption2).foregroundStyle(Theme.orange)
                    Text(item.value).font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Blog Section

private struct BlogSection: View {
    let posts: [BlogPost]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.line")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.orange)
                Text("選手ブログ")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(posts.count)件")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            ForEach(Array(posts.prefix(5).enumerated()), id: \.element.id) { idx, post in
                if let url = URL(string: post.url) {
                    Link(destination: url) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(post.date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if posts.count > 5 {
                Link(destination: URL(string: "https://anclas.jp/category/blog/")!) {
                    Text("すべてのブログを見る →")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.orange)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, pos) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Goal Badge（ヒーロー右下）

private struct GoalBadge: View {
    let scorer: ScorerRank

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "soccerball")
                    .font(.subheadline)
                    .foregroundStyle(Theme.orange)
                Text("\(scorer.goals)")
                    .font(.system(size: 36, weight: .heavy)).monospacedDigit()
                    .foregroundStyle(.white)
            }
            Text("GOALS")
                .font(.caption2.weight(.heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.8))
            Text("チーム\(scorer.rank)位")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.white.opacity(0.95), in: Capsule())
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            LinearGradient(colors: [Theme.orange, Theme.orange.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }
}
