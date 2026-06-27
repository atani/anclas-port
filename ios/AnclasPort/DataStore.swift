import Foundation

@Observable
@MainActor
final class DataStore {
    var matchesData: MatchesData?
    var standingsData: StandingsData?
    var playersData: PlayersData?
    var errorText: String?
    var isLoading = false

    private static let baseURL = "https://raw.githubusercontent.com/atani/anclas-port/main/data"

    func load() async {
        matchesData = matchesData ?? Self.loadLocal("matches")
        standingsData = standingsData ?? Self.loadLocal("standings")
        playersData = playersData ?? Self.loadLocal("players")
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        async let m: Void = fetchAndStore("matches", into: \DataStore.matchesData)
        async let s: Void = fetchAndStore("standings", into: \DataStore.standingsData)
        async let p: Void = fetchAndStore("players", into: \DataStore.playersData)
        _ = await (m, s, p)
    }

    // MARK: - convenience

    var data: MatchesData? { matchesData }

    // MARK: - internals

    private func fetchAndStore<T: Decodable>(_ name: String, into keyPath: ReferenceWritableKeyPath<DataStore, T?>) async {
        do {
            let url = URL(string: "\(Self.baseURL)/\(name).json")!
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 15
            let (bytes, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(T.self, from: bytes)
            self[keyPath: keyPath] = decoded
            try? bytes.write(to: Self.cacheURL(name), options: .atomic)
            errorText = nil
        } catch {
            if self[keyPath: keyPath] == nil {
                self[keyPath: keyPath] = Self.loadLocal(name)
            }
        }
    }

    private static func cacheURL(_ name: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("\(name).json")
    }

    private static func loadLocal<T: Decodable>(_ name: String) -> T? {
        if let data = try? Data(contentsOf: cacheURL(name)),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        return nil
    }
}
