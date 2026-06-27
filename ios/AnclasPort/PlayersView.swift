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
                if let players = store.playersData?.players {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(players) { player in
                            NavigationLink(value: player) {
                                PlayerCell(player: player)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                } else {
                    ProgressView("読み込み中…").padding(.top, 60)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("選手名鑑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                .foregroundStyle(Theme.navy)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AsyncImage(url: URL(string: player.photo.large ?? player.photo.full ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    default:
                        Color(.tertiarySystemFill).frame(height: 300)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 4) {
                    Text(player.displayNumber)
                        .font(.system(size: 40, weight: .heavy)).monospacedDigit()
                        .foregroundStyle(Theme.navy)
                    Text(player.nameJa)
                        .font(.title2.weight(.bold))
                    if let en = player.nameEn {
                        Text(en).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let pos = player.position {
                        Text(pos)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Theme.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.blue)
                    }
                }

                if hasProfile {
                    ProfileSection(player: player)
                }

                if !player.personal.isEmpty {
                    PersonalSection(items: player.personal)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasProfile: Bool {
        [player.profile.birthdate, player.profile.hometown, player.profile.height, player.profile.career]
            .contains(where: { $0 != nil })
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
                Text(career).font(.subheadline)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("PERSONAL").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(items, id: \.label) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).font(.caption2).foregroundStyle(.secondary)
                        Text(item.value).font(.caption)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
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
