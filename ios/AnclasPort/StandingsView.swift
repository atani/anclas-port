import SwiftUI

struct StandingsView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("順位表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable { await store.refresh() }
        }
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
                .foregroundStyle(row.isAnclas ? Theme.blue : .primary)

            Text(row.team)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(row.isAnclas ? Theme.blue : .primary)

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
        .background(row.isAnclas ? Theme.blue.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
