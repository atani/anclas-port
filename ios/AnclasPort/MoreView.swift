import SwiftUI

struct MoreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HeaderBar(title: "もっと")

                linkGroup("ニュース・レポート", items: [
                    .init("クラブニュース", "newspaper.fill", "https://anclas.jp/category/news/"),
                    .init("マッチレポート", "sportscourt.fill", "https://anclas.jp/category/match/"),
                    .init("選手ブログ", "pencil.line", "https://anclas.jp/category/blog/"),
                ])

                linkGroup("ポッドキャスト", items: [
                    .init("アンクラスのロッカールーム", "headphones", "https://open.spotify.com/show/3RnkWRyIMYe9IdtMmK7KFK", "Spotify で聴く"),
                ])

                linkGroup("公式SNS・サイト", items: [
                    .init("公式サイト", "globe", "https://anclas.jp/"),
                    .init("Instagram", "camera.fill", "https://www.instagram.com/anclas_fukuoka_official"),
                    .init("X（旧Twitter）", "bird.fill", "https://x.com/anclas_fukuoka"),
                ])

                linkGroup("リーグ情報", items: [
                    .init("GoalNote（全試合詳細）", "chart.bar.doc.horizontal.fill", "https://www.goalnote.net/detail-schedule.php?tid=18626"),
                    .init("九州女子サッカーリーグ", "trophy.fill", "https://q-league.net/"),
                ])

                appInfo
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func linkGroup(_ title: String, items: [LinkItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    LinkRow(item: item)
                    if idx < items.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .anclasCard(padding: 0)
            .padding(.horizontal, 16)
        }
    }

    private var appInfo: some View {
        VStack(spacing: 8) {
            Image("Emblem")
                .resizable().aspectRatio(contentMode: .fit)
                .frame(height: 44)
                .opacity(0.6)
            Text("アンクラス Port")
                .font(.subheadline.weight(.semibold))
            Text("v0.1.0　非公式ファンアプリ")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }
}

private struct LinkItem: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let url: String
    let subtitle: String?
    init(_ label: String, _ icon: String, _ url: String, _ subtitle: String? = nil) {
        self.label = label; self.icon = icon; self.url = url; self.subtitle = subtitle
    }
}

private struct LinkRow: View {
    let item: LinkItem
    var body: some View {
        if let url = URL(string: item.url) {
            Link(destination: url) {
                HStack(spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Theme.orange, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                        if let sub = item.subtitle {
                            Text(sub).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }
}
