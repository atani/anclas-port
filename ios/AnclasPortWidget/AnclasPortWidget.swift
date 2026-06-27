import WidgetKit
import SwiftUI

// MARK: - Colors (Widget Extension は本体と共有不可なので直接定義)

private let brandOrange = Color(red: 0.937, green: 0.424, blue: 0.000)
private let brandNavy = Color(red: 0.086, green: 0.176, blue: 0.400)

// MARK: - Models (Widget 用に最小限の型を定義)

struct WidgetMatchesData: Codable {
    let anclas: WidgetAnclasDerived
}

struct WidgetAnclasDerived: Codable {
    let nextMatch: WidgetMatch?
}

struct WidgetMatch: Codable {
    let competition: String
    let round: Int?
    let datetime: String
    let homeTeam: String
    let awayTeam: String
    let venue: String?

    static let anclasName = "福岡J・アンクラス"

    var opponent: String {
        homeTeam == Self.anclasName ? awayTeam : homeTeam
    }

    var isHome: Bool {
        homeTeam == Self.anclasName
    }

    var roundLabel: String {
        round.map { "第\($0)節" } ?? ""
    }

    var startDate: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: datetime)
    }
}

// MARK: - Timeline Entry

struct NextMatchEntry: TimelineEntry {
    let date: Date
    let match: WidgetMatch?
}

// MARK: - Timeline Provider

struct NextMatchProvider: TimelineProvider {
    private static let dataURL = URL(
        string: "https://raw.githubusercontent.com/atani/anclas-port/main/data/matches.json"
    )!

    func placeholder(in context: Context) -> NextMatchEntry {
        NextMatchEntry(date: .now, match: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextMatchEntry) -> Void) {
        fetchNext { match in
            completion(NextMatchEntry(date: .now, match: match))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextMatchEntry>) -> Void) {
        fetchNext { match in
            let entry = NextMatchEntry(date: .now, match: match)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchNext(completion: @escaping (WidgetMatch?) -> Void) {
        var req = URLRequest(url: Self.dataURL)
        req.timeoutInterval = 10
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let decoded = try? JSONDecoder().decode(WidgetMatchesData.self, from: data) else {
                completion(nil)
                return
            }
            completion(decoded.anclas.nextMatch)
        }.resume()
    }
}

// MARK: - Widget Views

struct NextMatchSmallView: View {
    let entry: NextMatchEntry

    var body: some View {
        if let match = entry.match {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "sportscourt.fill")
                        .font(.caption2)
                    Text("NEXT")
                        .font(.caption2.weight(.heavy))
                }
                .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Text(match.opponent)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let d = match.startDate {
                    Text(formatDate(d))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                if let d = match.startDate {
                    let days = daysFromNow(d)
                    Text(days <= 0 ? "TODAY" : "あと\(days)日")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(brandOrange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .containerBackground(for: .widget) {
                brandNavy
            }
        } else {
            VStack {
                Image(systemName: "sportscourt.fill")
                    .font(.title3)
                Text("次節調整中")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.6))
            .containerBackground(for: .widget) {
                brandNavy
            }
        }
    }
}

struct NextMatchMediumView: View {
    let entry: NextMatchEntry

    var body: some View {
        if let match = entry.match {
            HStack(spacing: 16) {
                // 左: カウントダウン
                VStack(spacing: 4) {
                    if let d = match.startDate {
                        let days = daysFromNow(d)
                        Text(days <= 0 ? "TODAY" : "\(days)")
                            .font(.system(size: 36, weight: .heavy))
                            .foregroundStyle(brandOrange)
                        if days > 0 {
                            Text("日後")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .frame(width: 70)

                // 右: 試合情報
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(match.competition) \(match.roundLabel)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(brandOrange)

                    HStack(spacing: 6) {
                        Text(match.isHome ? "H" : "A")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(brandOrange)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        Text("vs \(match.opponent)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    if let d = match.startDate {
                        Label(formatDate(d), systemImage: "calendar")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    if let venue = match.venue {
                        Label(venue, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(14)
            .containerBackground(for: .widget) {
                brandNavy
            }
        } else {
            HStack {
                Image(systemName: "sportscourt.fill")
                    .font(.title2)
                Text("次節調整中")
                    .font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.6))
            .containerBackground(for: .widget) {
                brandNavy
            }
        }
    }
}

// MARK: - Helpers

private func formatDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.timeZone = TimeZone(identifier: "Asia/Tokyo")
    f.dateFormat = "M/d(E) HH:mm"
    return f.string(from: date)
}

private func daysFromNow(_ target: Date) -> Int {
    let cal = Calendar(identifier: .gregorian)
    let start = cal.startOfDay(for: Date())
    let end = cal.startOfDay(for: target)
    return cal.dateComponents([.day], from: start, to: end).day ?? 0
}

// MARK: - Widget Configuration

@main
struct AnclasPortWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextMatchWidget()
    }
}

struct NextMatchWidget: Widget {
    let kind = "NextMatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextMatchProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                NextMatchWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("次の試合")
        .description("福岡J・アンクラスの次の試合情報を表示します")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextMatchWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NextMatchEntry

    var body: some View {
        switch family {
        case .systemMedium:
            NextMatchMediumView(entry: entry)
        default:
            NextMatchSmallView(entry: entry)
        }
    }
}
