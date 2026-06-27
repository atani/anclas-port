import Foundation

/// data/matches.json のスキーマに対応するモデル。
/// 中継（GitHub Actions）側が生成するため、アプリはデコードして表示するだけ。

struct MatchesData: Codable {
    let generatedAt: String
    let season: String
    let anclas: AnclasDerived
    let matches: [Match]
}

struct AnclasDerived: Codable {
    /// 次の未消化アンクラス試合（最も近い未来）
    let nextMatch: Match?
    /// 直近の確定アンクラス試合（最も新しい過去）
    let latestResult: Match?
}

struct Score: Codable, Hashable {
    let home: Int
    let away: Int
}

struct Match: Codable, Identifiable, Hashable {
    let id: String
    let competition: String
    let round: Int?
    let date: String
    let kickoff: String?
    let datetime: String
    let homeTeam: String
    let awayTeam: String
    let status: String
    let score: Score?
    let isAnclas: Bool
    let sourceUrl: String
}

// MARK: - 表示用の派生ロジック（アンクラス視点）

extension Match {
    static let anclasName = "福岡J・アンクラス"

    /// ISO8601（+09:00）をパース
    var startDate: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: datetime)
    }

    var isFinished: Bool { status == "finished" }

    /// アンクラスがホームか
    var anclasIsHome: Bool { homeTeam == Self.anclasName }

    /// 対戦相手の名前
    var opponent: String { anclasIsHome ? awayTeam : homeTeam }

    /// 節の表示（"第11節" / round が無ければ空）
    var roundLabel: String { round.map { "第\($0)節" } ?? "" }

    enum Outcome { case win, draw, lose }

    /// アンクラス視点の勝敗（確定試合のみ）
    var anclasOutcome: Outcome? {
        guard let score, isFinished else { return nil }
        let mine = anclasIsHome ? score.home : score.away
        let theirs = anclasIsHome ? score.away : score.home
        if mine > theirs { return .win }
        if mine < theirs { return .lose }
        return .draw
    }

    /// アンクラスの得点・失点（確定試合のみ）
    var anclasScoreLine: (mine: Int, theirs: Int)? {
        guard let score else { return nil }
        return anclasIsHome ? (score.home, score.away) : (score.away, score.home)
    }
}
