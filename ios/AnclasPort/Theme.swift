import SwiftUI

/// アンクラスのクラブカラー（エンブレム・キャラクター・公式サイトから採取）
/// ADR-001 に採取根拠を記録
enum Theme {
    /// クラブオレンジ #EF6C00（キャラクターのユニフォーム・サイトアクセント）
    static let orange = Color(red: 0.937, green: 0.424, blue: 0.000)
    /// エンブレム内側のダークネイビー #162D66（錨・文字）
    static let navy = Color(red: 0.086, green: 0.176, blue: 0.400)
    /// エンブレム外輪のブルー #1970C1
    static let blue = Color(red: 0.098, green: 0.439, blue: 0.757)
    /// キャラクターのイエロー #EDA016
    static let yellow = Color(red: 0.929, green: 0.627, blue: 0.086)

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
    func formattedJa(_ template: String = "M/d(E) HH:mm") -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = template
        return f.string(from: self)
    }

    func daysFromNow() -> Int {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: self)
        return cal.dateComponents([.day], from: start, to: target).day ?? 0
    }
}
