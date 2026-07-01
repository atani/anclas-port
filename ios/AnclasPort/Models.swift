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
    let nextMatch: Match?
    let latestResult: Match?
    let latestPodcast: PodcastEpisode?
    let latestYouTube: YouTubeVideo?
    let latestYouTubeShort: YouTubeVideo?
    let shopItems: [ShopItem]?
}

struct YouTubeVideo: Codable, Hashable {
    let videoId: String
    let title: String
    let thumbnailUrl: String
    let url: String
    let publishedAt: String

    var isNew: Bool {
        let f = ISO8601DateFormatter()
        guard let date = f.date(from: publishedAt) else { return false }
        return date.timeIntervalSinceNow > -7 * 24 * 60 * 60
    }
}

struct ShopItem: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let price: String
    let imageUrl: String
    let url: String
}

struct PodcastEpisode: Codable, Hashable {
    let title: String
    let thumbnailUrl: String
    let showUrl: String
    let embedUrl: String
    let publishedAt: String?

    var isNew: Bool {
        guard let pubDate = publishedAt else { return false }
        guard let date = ISO8601DateFormatter().date(from: pubDate + "T00:00:00+09:00") else { return false }
        return date.timeIntervalSinceNow > -7 * 24 * 60 * 60
    }
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
    let venue: String?
    let goals: [GoalEvent]?
    let starters: [MatchPlayer]?
    let subs: [MatchPlayer]?
    let substitutions: [SubstitutionEvent]?
    let cards: [CardEvent]?
    let stats: MatchStats?
    let matchReport: MatchReport?
    let photoGallery: [String]?
    let goalnoteUrl: String?
    let posterUrl: String?
    let matchdayProgramUrl: String?
}

struct MatchReport: Codable, Hashable {
    let summary: String
    let coachComment: CoachComment?
    let playerComments: [PlayerComment]
    let sourceUrl: String
}

struct CoachComment: Codable, Hashable {
    let name: String
    let comment: String
}

struct PlayerComment: Codable, Hashable, Identifiable {
    let name: String
    let number: Int?
    let comment: String
    var id: String { "\(name)-\(number ?? 0)" }
}

struct MatchPlayer: Codable, Hashable, Identifiable {
    let number: Int
    let position: String
    let name: String
    let team: String

    var id: String { "\(team)-\(number)-\(name)" }
}

struct CardEvent: Codable, Hashable, Identifiable {
    let number: Int
    let name: String
    let team: String
    let type: String  // "yellow" | "red"

    var id: String { "\(team)-\(number)-\(type)" }
}

struct SubstitutionEvent: Codable, Hashable, Identifiable {
    let minute: String
    let team: String
    let outNumber: Int
    let outName: String
    let inNumber: Int
    let inName: String

    var id: String { "\(minute)-\(outNumber)-\(inNumber)" }
}

struct MatchStats: Codable, Hashable {
    let attendance: String?
    let weather: String?
    let temperature: String?
    let pitch: String?
}

struct GoalEvent: Codable, Hashable, Identifiable {
    let minute: String
    let team: String
    let playerNumber: Int?
    let playerName: String
    let assist: String?

    var id: String { "\(minute)-\(playerName)" }
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

// MARK: - standings.json

struct StandingsData: Codable {
    let generatedAt: String
    let season: String
    let competition: String
    let table: [StandingRow]
    let scorers: [ScorerRank]?
    let assists: [AssistRank]?
}

struct AssistRank: Codable, Identifiable {
    let rank: Int
    let name: String
    let number: Int?
    let assists: Int

    var id: String { "\(rank)-\(name)" }
}

struct ScorerRank: Codable, Identifiable {
    let rank: Int          // チーム内順位
    let leagueRank: Int?   // リーグ全体順位
    let name: String
    let number: Int?
    let goals: Int

    var id: String { "\(rank)-\(name)" }
}

struct StandingRow: Codable, Identifiable {
    let rank: Int
    let team: String
    let played: Int
    let win: Int
    let draw: Int
    let loss: Int
    let gf: Int
    let ga: Int
    let gd: Int
    let points: Int
    let isAnclas: Bool

    var id: String { team }
}

// MARK: - players.json

struct PlayersData: Codable {
    let generatedAt: String
    let season: String
    let players: [Player]
}

struct PlayerPhoto: Codable, Hashable {
    let thumbnail: String?
    let medium: String?
    let large: String?
    let full: String?
}

struct PlayerProfile: Codable, Hashable {
    let birthdate: String?
    let hometown: String?
    let height: String?
    let bloodType: String?
    let career: String?
}

struct PersonalItem: Codable, Hashable {
    let label: String
    let value: String
}

struct BlogPost: Codable, Hashable, Identifiable {
    let title: String
    let url: String
    let date: String

    var id: String { url }
}

struct PlayerSns: Codable, Hashable {
    let instagram: String?
    let x: String?
    let tiktok: String?
    let youtube: String?

    var isEmpty: Bool {
        instagram == nil && x == nil && tiktok == nil && youtube == nil
    }
}

struct Player: Codable, Identifiable, Hashable {
    let id: Int
    let number: Int?
    let position: String?
    let nameJa: String
    let nameEn: String?
    let nickname: String?
    let photo: PlayerPhoto
    let profile: PlayerProfile
    let personal: [PersonalItem]
    let sourceUrl: String
    let blogPosts: [BlogPost]?
    let sns: PlayerSns?

    var displayNumber: String { number.map { "#\($0)" } ?? "" }
}
