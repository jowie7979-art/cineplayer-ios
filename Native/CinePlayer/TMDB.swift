import Foundation

enum TMDB {
    private static let sleutel = "e716f19ab4d25edc5247239a8f3494f8"

    static func beeld(_ pad: String?, _ maat: String = "w342") -> URL? {
        guard let pad, !pad.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(maat)\(pad)")
    }

    static func haal<T: Decodable>(_ pad: String, _ extra: [String: String] = [:]) async -> T? {
        guard var c = URLComponents(string: "https://api.themoviedb.org/3" + pad) else { return nil }
        var items = extra.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "api_key", value: sleutel))
        items.append(URLQueryItem(name: "language", value: "nl-NL"))
        c.queryItems = items
        guard let url = c.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}
