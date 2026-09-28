import Foundation
import Observation

@Observable
final class Bibliotheek {
    var favorieten: [Bewaard] = []
    var geschiedenis: [Bewaard] = []
    var zoekopdrachten: [String] = []
    var bron: Bron = .moviesapi
    var speelt: Afspelen?

    private let opslag = UserDefaults.standard

    init() {
        favorieten = laad("favorieten")
        geschiedenis = laad("geschiedenis")
        zoekopdrachten = opslag.stringArray(forKey: "zoekopdrachten") ?? []
        bron = Bron(rawValue: opslag.string(forKey: "bron") ?? "") ?? .moviesapi
    }

    // MARK: favorieten

    func isFavoriet(_ k: Keuze) -> Bool {
        favorieten.contains { $0.tmdb == k.tmdb && $0.serie == k.serie }
    }

    func wisselFavoriet(_ k: Keuze) {
        if isFavoriet(k) {
            favorieten.removeAll { $0.tmdb == k.tmdb && $0.serie == k.serie }
        } else {
            favorieten.insert(Bewaard(tmdb: k.tmdb, serie: k.serie, naam: k.naam, poster: k.poster,
                                      backdrop: k.backdrop, seizoen: 1, aflevering: 1, tijd: .now), at: 0)
        }
        bewaar(favorieten, "favorieten")
    }

    // MARK: geschiedenis

    func stand(_ k: Keuze) -> Bewaard? {
        geschiedenis.first { $0.tmdb == k.tmdb && $0.serie == k.serie }
    }

    func verwijder(_ b: Bewaard) {
        geschiedenis.removeAll { $0.id == b.id }
        bewaar(geschiedenis, "geschiedenis")
    }

    func wisGeschiedenis() {
        geschiedenis = []
        bewaar(geschiedenis, "geschiedenis")
    }

    // MARK: afspelen

    func speel(_ k: Keuze, seizoen: Int = 1, aflevering: Int = 1, seizoenen: [Seizoen] = []) {
        onthoud(k, seizoen: seizoen, aflevering: aflevering)
        speelt = Afspelen(keuze: k, seizoen: seizoen, aflevering: aflevering, seizoenen: seizoenen)
    }

    func onthoud(_ k: Keuze, seizoen: Int, aflevering: Int) {
        geschiedenis.removeAll { $0.tmdb == k.tmdb && $0.serie == k.serie }
        geschiedenis.insert(Bewaard(tmdb: k.tmdb, serie: k.serie, naam: k.naam, poster: k.poster,
                                    backdrop: k.backdrop, seizoen: seizoen, aflevering: aflevering, tijd: .now), at: 0)
        if geschiedenis.count > 40 { geschiedenis = Array(geschiedenis.prefix(40)) }
        bewaar(geschiedenis, "geschiedenis")
    }

    func kiesBron(_ b: Bron) {
        bron = b
        opslag.set(b.rawValue, forKey: "bron")
    }

    // MARK: zoeken

    func onthoudZoekopdracht(_ q: String) {
        let t = q.trimmingCharacters(in: .whitespaces)
        guard t.count > 1 else { return }
        zoekopdrachten.removeAll { $0.caseInsensitiveCompare(t) == .orderedSame }
        zoekopdrachten.insert(t, at: 0)
        zoekopdrachten = Array(zoekopdrachten.prefix(8))
        opslag.set(zoekopdrachten, forKey: "zoekopdrachten")
    }

    func wisZoekopdrachten() {
        zoekopdrachten = []
        opslag.set(zoekopdrachten, forKey: "zoekopdrachten")
    }

    // MARK: opslag

    private func laad(_ sleutel: String) -> [Bewaard] {
        guard let data = opslag.data(forKey: sleutel) else { return [] }
        return (try? JSONDecoder().decode([Bewaard].self, from: data)) ?? []
    }

    private func bewaar(_ lijst: [Bewaard], _ sleutel: String) {
        if let data = try? JSONEncoder().encode(lijst) { opslag.set(data, forKey: sleutel) }
    }
}
