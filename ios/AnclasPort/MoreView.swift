import SwiftUI

struct MoreView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderBar(title: "もっと")

                // ニュース
                LinkSection(title: "ニュース", items: [
                    LinkItem(icon: "newspaper.fill", label: "クラブニュース", url: "https://anclas.jp/category/news/"),
                    LinkItem(icon: "sportscourt.fill", label: "マッチレポート", url: "https://anclas.jp/category/match/"),
                    LinkItem(icon: "pencil.line", label: "選手ブログ", url: "https://anclas.jp/category/blog/"),
                ])

                // ポッドキャスト
                LinkSection(title: "ポッドキャスト", items: [
                    LinkItem(icon: "headphones", label: "アンクラスのロッカールーム", subtitle: "Spotify で聴く", url: "https://open.spotify.com/show/3RnkWRyIMYe9IdtMmK7KFK"),
                ])

                // クラブ情報
                LinkSection(title: "クラブ情報", items: [
                    LinkItem(icon: "globe", label: "公式サイト", url: "https://anclas.jp/"),
                    LinkItem(icon: "camera.fill", label: "Instagram", url: "https://www.instagram.com/anclas_fukuoka/"),
                    LinkItem(icon: "xmark.square.fill", label: "X (Twitter)", url: "https://x.com/anclas_fukuoka"),
                ])

                // GoalNote
                LinkSection(title: "リーグ情報", items: [
                    LinkItem(icon: "chart.bar.doc.horizontal.fill", label: "GoalNote（全試合詳細）", url: "https://www.goalnote.net/detail-schedule.php?tid=18626"),
                    LinkItem(icon: "sportscourt", label: "九州女子サッカーリーグ", url: "https://q-league.net/"),
                ])

                // アプリ情報
                VStack(alignment: .center, spacing: 6) {
                    Image("Emblem")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 40)
                        .opacity(0.5)
                    Text("アンクラス Port v0.1.0")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("非公式アプリ")
                        .font(.caption2).foregroundStyle(.quaternary)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct LinkItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    var subtitle: String? = nil
    let url: String
}

private struct LinkSection: View {
    let title: String
    let items: [LinkItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    if let url = URL(string: item.url) {
                        Link(destination: url) {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.body)
                                    .foregroundStyle(Theme.orange)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label).font(.subheadline)
                                    if let sub = item.subtitle {
                                        Text(sub).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if item.id != items.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        }
    }
}
