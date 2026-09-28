import SwiftUI

enum Sortering: String, CaseIterable, Identifiable {
    case populair, beoordeling, nieuw
    var id: String { rawValue }
    var naam: String {
        switch self {
        case .populair: return "Populair"
        case .beoordeling: return "Best beoordeeld"
        case .nieuw: return "Nieuw"
        }
    }
}

struct ThuisScherm: View {
    @Environment(Bibliotheek.self) private var bib
    @State private var serie = false
    @State private var genres: [Genre] = []
    @State private var genre: Genre?
    @State private var sortering: Sortering = .populair
    @State private var titels: [Titel] = []
    @State private var pagina = 1
    @State private var totaal = 1
    @State private var laden = false
    @State private var uitgelicht: [Titel] = []

    private var sleutel: String { "\(serie)-\(genre?.id ?? 0)-\(sortering.rawValue)" }
    private var soort: String { serie ? "tv" : "movie" }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if !uitgelicht.isEmpty {
                        Uitgelicht(titels: uitgelicht, serie: serie)
                    }
                    if !bib.geschiedenis.isEmpty {
                        Rij(titel: "Verder kijken") {
                            ForEach(bib.geschiedenis) { b in
                                NavigationLink(value: b.keuze) { BewaardKaart(bewaard: b, toonStand: true) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    if !bib.favorieten.isEmpty {
                        Rij(titel: "Favorieten") {
                            ForEach(bib.favorieten) { b in
                                NavigationLink(value: b.keuze) { BewaardKaart(bewaard: b) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    filters
                    raster
                }
                .padding(.bottom, 24)
            }
            .background(Color.achtergrond)
            .navigationTitle(serie ? "Series" : "Films")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Soort", selection: $serie) {
                        Text("Films").tag(false)
                        Text("Series").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
            .navigationDestination(for: Keuze.self) { DetailScherm(keuze: $0) }
            .task(id: serie) {
                genre = nil
                async let g: GenreLijst? = TMDB.haal("/genre/\(soort)/list")
                async let u: Pagina? = TMDB.haal("/trending/\(soort)/week")
                genres = await g?.genres ?? []
                uitgelicht = Array((await u?.results ?? []).filter { $0.backdrop_path != nil }.prefix(6))
            }
            .task(id: sleutel) { await laad(opnieuw: true) }
            .refreshable { await laad(opnieuw: true) }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(genre?.name ?? sortering.naam)
                    .font(.kop(22))
                Spacer()
                Menu {
                    Picker("Sorteren", selection: $sortering) {
                        ForEach(Sortering.allCases) { Text($0.naam).tag($0) }
                    }
                } label: {
                    Label(sortering.naam, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Keuzechip(tekst: "Alles", actief: genre == nil) { genre = nil }
                    ForEach(genres) { g in
                        Keuzechip(tekst: g.name, actief: genre == g) { genre = g }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var raster: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 18) {
            ForEach(titels) { t in
                NavigationLink(value: t.keuze(serie)) { TitelKaart(titel: t, serie: serie) }
                    .buttonStyle(.plain)
                    .onAppear {
                        if t.id == titels.last?.id { Task { await laad(opnieuw: false) } }
                    }
            }
        }
        .padding(.horizontal)
        .overlay(alignment: .top) {
            if titels.isEmpty && laden { ProgressView().padding(.top, 40) }
        }
    }

    private func laad(opnieuw: Bool) async {
        if laden && !opnieuw { return }
        if !opnieuw && pagina >= totaal { return }
        let volgende = opnieuw ? 1 : pagina + 1
        laden = true
        defer { laden = false }

        var pad = "/discover/\(soort)"
        var extra: [String: String] = ["page": String(volgende)]
        if let genre { extra["with_genres"] = String(genre.id) }
        switch sortering {
        case .populair:
            if genre == nil { pad = "/\(soort)/popular" } else { extra["sort_by"] = "popularity.desc" }
        case .beoordeling:
            extra["sort_by"] = "vote_average.desc"
            extra["vote_count.gte"] = "300"
        case .nieuw:
            let datum = serie ? "first_air_date" : "primary_release_date"
            extra["sort_by"] = datum + ".desc"
            extra[datum + ".lte"] = Date.now.formatted(.iso8601.year().month().day())
            extra["vote_count.gte"] = "20"
        }

        let vorige = sleutel
        guard let p: Pagina = await TMDB.haal(pad, extra), vorige == sleutel else { return }
        pagina = p.page
        totaal = min(p.total_pages, 25)
        if opnieuw {
            titels = p.results
        } else {
            let bekend = Set(titels.map(\.id))
            titels += p.results.filter { !bekend.contains($0.id) }
        }
    }
}

struct Uitgelicht: View {
    let titels: [Titel]
    let serie: Bool
    @State private var keuze = 0

    var body: some View {
        TabView(selection: $keuze) {
            ForEach(Array(titels.enumerated()), id: \.element.id) { i, t in
                NavigationLink(value: t.keuze(serie)) {
                    Color.kaart
                        .overlay { Beeld(pad: t.backdrop_path, maat: "w1280") }
                        .overlay {
                            LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.9)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Veel bekeken deze week")
                                    .font(.caption2.weight(.semibold))
                                    .textCase(.uppercase)
                                    .tracking(1.5)
                                    .foregroundStyle(Color.goud)
                                Text(t.naam)
                                    .font(.kop(26))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                            }
                            .padding(18)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 240)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                guard !titels.isEmpty else { continue }
                withAnimation(.easeInOut(duration: 0.6)) { keuze = (keuze + 1) % titels.count }
            }
        }
    }
}
