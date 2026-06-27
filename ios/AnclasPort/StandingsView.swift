import SwiftUI

struct StandingsView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeaderBar(title: "順位表")

                if let data = store.standingsData {
                    VStack(spacing: 0) {
                        ColumnHeader()
                        ForEach(Array(data.table.enumerated()), id: \.element.id) { idx, row in
                            StandingRowView(row: row, isLast: idx == data.table.count - 1)
                        }
                    }
                    .anclasCard(padding: 0)
                    .padding(.horizontal, 16)

                    Text("\(data.competition)　\(data.season)シーズン")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    LoadingState(message: "順位表を読み込み中…")
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await store.refresh() }
    }
}

private struct ColumnHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("順").frame(width: 36)
            Text("チーム").frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text("試"); Text("勝"); Text("分"); Text("敗")
            }
            .frame(width: 26)
            Text("勝点").frame(width: 40)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.navy.opacity(0.06))
    }
}

private struct StandingRowView: View {
    let row: StandingRow
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                RankBadge(rank: row.rank, isAnclas: row.isAnclas)
                    .frame(width: 36)

                Text(row.team)
                    .font(.callout.weight(row.isAnclas ? .bold : .regular))
                    .foregroundStyle(row.isAnclas ? Theme.orange : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    Text("\(row.played)").foregroundStyle(.secondary)
                    Text("\(row.win)")
                    Text("\(row.draw)")
                    Text("\(row.loss)")
                }
                .font(.callout.monospacedDigit())
                .frame(width: 26)

                Text("\(row.points)")
                    .font(.body.weight(.heavy).monospacedDigit())
                    .foregroundStyle(row.isAnclas ? Theme.orange : .primary)
                    .frame(width: 40)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(row.isAnclas ? Theme.orange.opacity(0.10) : Color.clear)
            .overlay(alignment: .leading) {
                if row.isAnclas {
                    Rectangle().fill(Theme.orange).frame(width: 4)
                }
            }

            if !isLast {
                Divider().padding(.leading, 14)
            }
        }
    }
}

private struct RankBadge: View {
    let rank: Int
    let isAnclas: Bool

    private var color: Color {
        switch rank {
        case 1: return Theme.orange
        case 2: return Color(.systemGray)
        case 3: return Theme.yellow
        default: return Color(.systemGray3)
        }
    }

    var body: some View {
        Text("\(rank)")
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(rank <= 3 ? .white : .secondary)
            .frame(width: 26, height: 26)
            .background(rank <= 3 ? color : Color.clear, in: Circle())
    }
}
