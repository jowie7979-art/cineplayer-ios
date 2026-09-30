import SwiftUI

struct DetailScherm: View {
    @Environment(Bibliotheek.self) private var bib
    let keuze: Keuze
    @State private var details: Details?
    @State private var seizoen = 1
    @State private var afleveringen: [Aflevering] = []
    @State private var trek: CGFloat = 0

    private var seizoenen: [Seizoen] { (details?.seasons ?? []).filter { $0.season_number > 0 } }
    private var stand: Bewaard? { bib.stand(keuze) }
    /// Wat Afspelen zou starten: dat laadt de Voorlader alvast.
    private var voorAdres: String {
        bib.bron.adres(keuze.tmdb, serie: keuze.serie, seizoen: stand?.seizoen ?? 1, aflevering: stand?.aflevering ?? 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                kop
                VStack(alignment: .leading, spacing: 16) {
                    knoppen
                    if let o = details?.overview, !o.isEmpty {
                        Text(o)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    if keuze.serie && !seizoenen.isEmpty {
                        afleveringLijst
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .onScrollGeometryChange(for: CGFloat.self) { g in
            g.contentOffset.y + g.contentInsets.top
        } action: { _, nieuw in
            trek = nieuw
        }
        .background(Color.achtergrond)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(duration: 0.35)) { bib.wisselFavoriet(keuze) }
                } label: {
                    Image(systemName: bib.isFavoriet(keuze) ? "heart.fill" : "heart")
                        .foregroundStyle(bib.isFavoriet(keuze) ? Color.red : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: bib.isFavoriet(keuze))
                }
                .accessibilityLabel(bib.isFavoriet(keuze) ? "Uit favorieten" : "Aan favorieten toevoegen")
                .sensoryFeedback(.impact(weight: .light), trigger: bib.isFavoriet(keuze))
            }
        }
        .onAppear { Voorlader.gedeeld.voorladen(voorAdres) }
        .onDisappear { Voorlader.gedeeld.verlaat(voorAdres) }
        .task {
            details = await TMDB.haal("/\(keuze.serie ? "tv" : "movie")/\(keuze.tmdb)")
            if let s = stand, seizoenen.contains(where: { $0.season_number == s.seizoen }) {
                seizoen = s.seizoen
            } else if let eerste = seizoenen.first {
                seizoen = eerste.season_number
            }
        }
        .task(id: seizoen) {
            guard keuze.serie else { return }
            afleveringen = []
            let d: SeizoenDetails? = await TMDB.haal("/tv/\(keuze.tmdb)/season/\(seizoen)")
            afleveringen = d?.episodes ?? []
        }
    }

    private var kop: some View {
        ZStack(alignment: .bottomLeading) {
            Color.kaart
                .frame(height: 340 + max(0, -trek))
                .overlay { Beeld(pad: details?.backdrop_path ?? keuze.backdrop ?? keuze.poster, maat: "w1280") }
                .clipped()
                .offset(y: min(0, trek))
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.3), .clear, Color.achtergrond.opacity(0.85), Color.achtergrond],
                                   startPoint: .top, endPoint: .bottom)
                }
            HStack(alignment: .bottom, spacing: 14) {
                PosterVlak(pad: details?.poster_path ?? keuze.poster, hoek: 10)
                    .frame(width: 104)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text(keuze.naam)
                        .font(.kop(28))
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                    if let t = details?.tagline, !t.isEmpty {
                        Text(t)
                            .font(.system(.footnote, design: .serif).italic())
                            .foregroundStyle(Color.goud.opacity(0.9))
                            .lineLimit(2)
                    }
                    Text(infoRegel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let v = details?.vote_average, v > 0 {
                        Label {
                            Text(v, format: .number.precision(.fractionLength(1)))
                        } icon: {
                            Image(systemName: "star.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.goud)
                    }
                }
            }
            .padding(.horizontal)
            .offset(y: 30)
        }
        .padding(.bottom, 30)
    }

    private var infoRegel: String {
        guard let d = details else { return keuze.serie ? "Serie" : "Film" }
        let jaar = String((d.release_date ?? d.first_air_date ?? "").prefix(4))
        var duur = ""
        if let r = d.runtime, r > 0 { duur = "\(r / 60) u \(r % 60) min" }
        if keuze.serie { duur = seizoenen.count == 1 ? "1 seizoen" : "\(seizoenen.count) seizoenen" }
        let genres = (d.genres ?? []).prefix(2).map(\.name).joined(separator: ", ")
        return [jaar, duur, genres].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var knoppen: some View {
        Button {
            if keuze.serie {
                bib.speel(keuze, seizoen: stand?.seizoen ?? 1, aflevering: stand?.aflevering ?? 1, seizoenen: seizoenen)
            } else {
                bib.speel(keuze)
            }
        } label: {
            Label(hoofdknop, systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .foregroundStyle(Color.achtergrond)
                .background(
                    LinearGradient(colors: [Color(red: 0.86, green: 0.74, blue: 0.51), Color.goud,
                                            Color(red: 0.70, green: 0.57, blue: 0.36)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.goud.opacity(0.25), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: bib.speelt?.id)
    }

    private var hoofdknop: String {
        guard let s = stand else { return "Afspelen" }
        return keuze.serie ? "Verder met \(s.stand)" : "Opnieuw afspelen"
    }

    private var afleveringLijst: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Afleveringen").font(.kop(20))
                Spacer()
                Menu {
                    Picker("Seizoen", selection: $seizoen) {
                        ForEach(seizoenen) { s in Text(s.name ?? "Seizoen \(s.season_number)").tag(s.season_number) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Seizoen \(seizoen)")
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            LazyVStack(spacing: 14) {
                if afleveringen.isEmpty {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 12) {
                            Skelet(verhouding: 16 / 9).frame(width: 132)
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.kaart).frame(height: 12)
                                RoundedRectangle(cornerRadius: 4).fill(Color.kaart).frame(width: 90, height: 10)
                            }
                        }
                    }
                }
                ForEach(afleveringen) { a in
                    AfleveringRegel(aflevering: a, stand: stand)
                        .transition(.opacity)
                        .onTapGesture {
                            bib.speel(keuze, seizoen: a.season_number, aflevering: a.episode_number, seizoenen: seizoenen)
                        }
                }
            }
        }
        .padding(.top, 8)
    }
}

struct AfleveringRegel: View {
    let aflevering: Aflevering
    let stand: Bewaard?

    private var huidig: Bool {
        stand?.seizoen == aflevering.season_number && stand?.aflevering == aflevering.episode_number
    }
    private var gezien: Bool {
        guard let s = stand else { return false }
        return aflevering.season_number < s.seizoen
            || (aflevering.season_number == s.seizoen && aflevering.episode_number < s.aflevering)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.kaart
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(width: 132)
                .overlay { Beeld(pad: aflevering.still_path, maat: "w300") }
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    if huidig {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.goud, lineWidth: 2)
                    }
                }
                .opacity(gezien ? 0.55 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(aflevering.episode_number). \(aflevering.name ?? "Aflevering \(aflevering.episode_number)")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(huidig ? Color.goud : .primary)
                    .lineLimit(2)
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(huidig ? Color.goud : .secondary)
                if let o = aflevering.overview, !o.isEmpty {
                    Text(o)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var meta: String {
        var delen: [String] = []
        if let r = aflevering.runtime, r > 0 { delen.append("\(r) min") }
        if huidig { delen.append("Hier gestopt") } else if gezien { delen.append("Gezien") }
        return delen.joined(separator: " · ")
    }
}
