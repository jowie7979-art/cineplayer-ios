import Foundation

enum TMDB {
    private static let sleutel = "e716f19ab4d25edc5247239a8f3494f8"
    /// Antwoorden bewaren zolang de app open is: terug naar een titel of lijst is dan direct.
    private static let cache = NSCache<NSURL, NSData>()

    static func beeld(_ pad: String?, _ maat: String = "w342") -> URL? {
        guard let pad, !pad.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(maat)\(pad)")
    }

    static func haal<T: Decodable>(_ pad: String, _ extra: [String: String] = [:]) async -> T? {
        guard var c = URLComponents(string: "https://api.themoviedb.org/3" + pad) else { return nil }
        var items = extra.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "api_key", value: sleutel))
        items.append(URLQueryItem(name: "language", value: "nl-NL"))
        c.queryItems = items
        guard let url = c.url else { return nil }
        if let d = cache.object(forKey: url as NSURL) { return try? JSONDecoder().decode(T.self, from: d as Data) }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let t = try JSONDecoder().decode(T.self, from: data)
            cache.setObject(data as NSData, forKey: url as NSURL)
            return t
        } catch {
            return nil
        }
    }
}
