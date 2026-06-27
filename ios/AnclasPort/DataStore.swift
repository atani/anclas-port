import Foundation

/// matches.json を取得・キャッシュして供給する。
/// オフライン耐性（UX原則6）のため、表示は「キャッシュ → バンドル」の順でフォールバックし、
/// リモート取得に成功したらキャッシュを更新する。
@Observable
@MainActor
final class DataStore {
    var data: MatchesData?
    var errorText: String?
    var isLoading = false

    /// GitHub Pages 設定前は raw を読む。Pages 公開後に差し替える。
    private let remoteURL = URL(
        string: "https://raw.githubusercontent.com/atani/anclas-port/main/data/matches.json"
    )!

    private static let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("matches.json")
    }()

    /// 起動時: 即座にローカル（キャッシュ→バンドル）を出し、その後リモート更新
    func load() async {
        if data == nil { data = Self.loadLocal() }
        await refresh()
    }

    /// リモートから取得して反映（pull-to-refresh からも呼ぶ）
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            var req = URLRequest(url: remoteURL)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 15
            let (bytes, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(MatchesData.self, from: bytes)
            data = decoded
            try? bytes.write(to: Self.cacheURL, options: .atomic)
            errorText = nil
        } catch {
            // リモート失敗時は既存表示（キャッシュ/バンドル）を維持
            if data == nil { data = Self.loadLocal() }
            errorText = "最新データを取得できませんでした（保存済みを表示中）"
        }
    }

    // MARK: - ローカル読み込み

    private static func loadLocal() -> MatchesData? {
        if let cached = decode(contentsOf: cacheURL) { return cached }
        if let url = Bundle.main.url(forResource: "matches", withExtension: "json") {
            return decode(contentsOf: url)
        }
        return nil
    }

    private static func decode(contentsOf url: URL) -> MatchesData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MatchesData.self, from: data)
    }
}
