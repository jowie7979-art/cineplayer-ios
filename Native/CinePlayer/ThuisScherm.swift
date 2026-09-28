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
    @State private var fout = false
    @Namespace private var zoom

    private var sleutel: String { "\(serie)-\(genre?.id ?? 0)-\(sortering.rawValue)" }
    private var soort: String { serie ? "tv" : "movie" }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if uitgelicht.isEmpty {
                        Skelet(verhouding: 16 / 10).padding(.horizontal).frame(height: 240)
                    } else {
                        Uitgelicht(titels: uitgelicht, serie: serie, zoom: zoom)
                    }
                    if !bib.geschiedenis.isEmpty {
                        Rij(titel: "Verder kijken") {
                            ForEach(bib.geschiedenis) { b in
                                Button {
                                    bib.speel(b.keuze, seizoen: b.seizoen, aflevering: b.aflevering)
                                } label: {
                                    VerderKaart(bewaard: b)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Weghalen uit Verder kijken", systemImage: "xmark.circle", role: .destructive) {
                                        withAnimation(.snappy) { bib.verwijder(b) }
                                    }
                                }
                                .scrollTransition(.interactive, axis: .horizontal) { c, f in
                                    c.scaleEffect(f.isIdentity ? 1 : 0.95).opacity(f.isIdentity ? 1 : 0.75)
                                }
                            }
                        }
                    }
                    if !bib.favorieten.isEmpty {
                        Rij(titel: "Favorieten") {
                            ForEach(bib.favorieten) { b in
                                NavigationLink(value: b.keuze) { BewaardKaart(bewaard: b) }
                                    .buttonStyle(.plain)
                                    .matchedTransitionSource(id: b.keuze, in: zoom)
                                    .scrollTransition(.interactive, axis: .horizontal) { c, f in
                                        c.scaleEffect(f.isIdentity ? 1 : 0.94).opacity(f.isIdentity ? 1 : 0.75)
                                    }
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
            .navigationDestination(for: Keuze.self) { k in
                DetailScherm(keuze: k).navigationTransition(.zoom(sourceID: k, in: zoom))
            }
            .task(id: serie) {
                genre = nil
                uitgelicht = []
                async let g: GenreLijst? = TMDB.haal("/genre/\(soort)/list")
                async let u: Pagina? = TMDB.haal("/trending/\(soort)/week")
                genres = await g?.genres ?? []
                uitgelicht = Array((await u?.results ?? []).filter { $0.backdrop_path != nil }.prefix(6))
            }
            .task(id: sleutel) {
                titels = []
                await laad(opnieuw: true)
            }
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
            if titels.isEmpty && !fout {
                ForEach(0..<12, id: \.self) { _ in Skelet() }
            }
            ForEach(titels) { t in
                NavigationLink(value: t.keuze(serie)) { TitelKaart(titel: t, serie: serie) }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: t.keuze(serie), in: zoom)
                    .onAppear {
                        if t.id == titels.last?.id { Task { await laad(opnieuw: false) } }
                    }
            }
        }
        .padding(.horizontal)
        .overlay(alignment: .top) {
            if titels.isEmpty && fout {
                ContentUnavailableView {
                    Label("Geen verbinding", systemImage: "wifi.slash")
                } description: {
                    Text("De titels konden niet worden geladen.")
                } actions: {
                    Button("Opnieuw proberen") { Task { await laad(opnieuw: true) } }
                        .buttonStyle(.borderedProminent)
                }
                .background(Color.achtergrond)
            }
        }
        .animation(.easeOut(duration: 0.25), value: titels.isEmpty)
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
        if opnieuw { fout = false }
        let antwoord: Pagina? = await TMDB.haal(pad, extra)
        guard vorige == sleutel else { return }
        guard let p = antwoord else {
            if opnieuw { titels = []; fout = true }
            return
        }
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
    let zoom: Namespace.ID
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
                                    .font(.kop(28))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                    Text("Bekijk")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.achtergrond)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.goud, in: Capsule())
                                .padding(.top, 4)
                            }
                            .padding(18)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                        }
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: t.keuze(serie), in: zoom)
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
