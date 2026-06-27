import SwiftUI

struct StandingsView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderBar(title: "順位表")
                    .padding(.bottom, 8)

                if let table = store.standingsData?.table {
                    VStack(spacing: 0) {
                        HeaderRow()
                        ForEach(table) { row in
                            StandingRowView(row: row)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                } else {
                    ProgressView("読み込み中…").padding(.top, 60)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await store.refresh() }
    }
}

private struct HeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("#").frame(width: 24, alignment: .center)
            Text("チーム").frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text("試")
                Text("勝")
                Text("分")
                Text("敗")
                Text("点")
            }
            .frame(width: 28, alignment: .center)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }
}

private struct StandingRowView: View {
    let row: StandingRow

    var body: some View {
        HStack(spacing: 0) {
            Text("\(row.rank)")
                .frame(width: 24, alignment: .center)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(row.isAnclas ? Theme.orange : .primary)

            Text(row.team)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(row.isAnclas ? Theme.orange : .primary)

            Group {
                Text("\(row.played)")
                Text("\(row.win)")
                Text("\(row.draw)")
                Text("\(row.loss)")
                Text("\(row.points)").fontWeight(.bold)
            }
            .frame(width: 28, alignment: .center)
            .font(.subheadline.monospacedDigit())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(row.isAnclas ? Theme.orange.opacity(0.12) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
