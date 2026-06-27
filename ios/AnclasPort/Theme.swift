import SwiftUI

/// クラブカラー（採取候補のネイビー）と勝敗色。
/// 確定は申請前にロゴ・ユニフォームから採る（design.md）。
enum Theme {
    /// アンクラスのネイビー #273349
    static let navy = Color(red: 0.153, green: 0.200, blue: 0.286)
    /// エンブレムの明るいブルー
    static let blue = Color(red: 0.176, green: 0.482, blue: 0.792)

    static let win = Color.green
    static let draw = Color.gray
    static let lose = Color.red

    static func outcomeColor(_ o: Match.Outcome) -> Color {
        switch o {
        case .win: win
        case .draw: draw
        case .lose: lose
        }
    }

    static func outcomeLabel(_ o: Match.Outcome) -> String {
        switch o {
        case .win: "WIN"
        case .draw: "DRAW"
        case .lose: "LOSE"
        }
    }
}

extension Date {
    /// "6/27(金) 12:00" 形式
    func formattedJa(_ template: String = "M/d(E) HH:mm") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = template
        return f.string(from: self)
    }

    /// 今日からの残り日数（キックオフ当日は 0）
    func daysFromNow() -> Int {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: self)
        return cal.dateComponents([.day], from: start, to: target).day ?? 0
    }
}
