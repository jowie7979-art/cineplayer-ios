import Foundation

struct Titel: Identifiable, Codable, Hashable {
    let id: Int
    let title: String?
    let name: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let first_air_date: String?
    let vote_average: Double?
    let overview: String?
    let media_type: String?

    var naam: String { title ?? name ?? "" }
    var jaar: String { String((release_date ?? first_air_date ?? "").prefix(4)) }

    func isSerie(_ standaard: Bool) -> Bool {
        if let m = media_type { return m == "tv" }
        if first_air_date != nil { return true }
        if release_date != nil { return false }
        return standaard
    }

    func keuze(_ standaard: Bool) -> Keuze {
        Keuze(tmdb: id, serie: isSerie(standaard), naam: naam, poster: poster_path, backdrop: backdrop_path)
    }
}

struct Pagina: Codable {
    let page: Int
    let total_pages: Int
    let results: [Titel]
}

struct Genre: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct GenreLijst: Codable { let genres: [Genre] }

struct Details: Codable {
    let id: Int
    let overview: String?
    let tagline: String?
    let backdrop_path: String?
    let poster_path: String?
    let vote_average: Double?
    let runtime: Int?
    let episode_run_time: [Int]?
    let genres: [Genre]?
    let release_date: String?
    let first_air_date: String?
    let seasons: [Seizoen]?
}

struct Seizoen: Codable, Identifiable, Hashable {
    let id: Int
    let season_number: Int
    let episode_count: Int
    let name: String?
}

struct SeizoenDetails: Codable { let episodes: [Aflevering]? }

struct Aflevering: Codable, Identifiable, Hashable {
    let id: Int
    let episode_number: Int
    let season_number: Int
    let name: String?
    let overview: String?
    let still_path: String?
    let runtime: Int?
    let air_date: String?
}

/// Wat je aantikt: genoeg om het detailscherm te openen.
struct Keuze: Hashable {
    let tmdb: Int
    let serie: Bool
    let naam: String
    let poster: String?
    let backdrop: String?
}

/// Favoriet of geschiedenis-item.
struct Bewaard: Codable, Identifiable, Hashable {
    var id: String { (serie ? "tv-" : "film-") + String(tmdb) }
    let tmdb: Int
    let serie: Bool
    let naam: String
    let poster: String?
    let backdrop: String?
    var seizoen: Int
    var aflevering: Int
    var tijd: Date

    var keuze: Keuze { Keuze(tmdb: tmdb, serie: serie, naam: naam, poster: poster, backdrop: backdrop) }
    var stand: String { "S\(seizoen) · A\(aflevering)" }
}

enum Bron: String, CaseIterable, Identifiable {
    case moviesapi, vidsrc, vixcloud
    var id: String { rawValue }

    var naam: String {
        switch self {
        case .moviesapi: return "MoviesAPI"
        case .vidsrc: return "VidSrc"
        case .vixcloud: return "VixCloud"
        }
    }

    func adres(_ id: Int, serie: Bool, seizoen s: Int, aflevering a: Int) -> String {
        switch (self, serie) {
        case (.moviesapi, false): return "https://moviesapi.to/movie/\(id)?lang=en"
        case (.moviesapi, true): return "https://moviesapi.to/tv/\(id)-\(s)-\(a)?lang=en"
        case (.vidsrc, false): return "https://vidsrc.to/embed/movie/\(id)?ds_lang=en"
        case (.vidsrc, true): return "https://vidsrc.to/embed/tv/\(id)/\(s)/\(a)?ds_lang=en"
        case (.vixcloud, false): return "https://vixsrc.to/movie/\(id)?sub_lang=en"
        case (.vixcloud, true): return "https://vixsrc.to/tv/\(id)/\(s)/\(a)?sub_lang=en"
        }
    }
}

/// Wat er nu speelt.
struct Afspelen: Identifiable, Equatable {
    let id = UUID()
    let keuze: Keuze
    var seizoen: Int
    var aflevering: Int
    var seizoenen: [Seizoen]

    var titel: String {
        keuze.serie ? "\(keuze.naam) · S\(seizoen) · A\(aflevering)" : keuze.naam
    }

    var volgende: (Int, Int)? {
        guard keuze.serie else { return nil }
        if let huidig = seizoenen.first(where: { $0.season_number == seizoen }), aflevering < huidig.episode_count {
            return (seizoen, aflevering + 1)
        }
        if seizoenen.contains(where: { $0.season_number == seizoen + 1 }) { return (seizoen + 1, 1) }
        return nil
    }

    static func == (l: Afspelen, r: Afspelen) -> Bool { l.id == r.id }
}
