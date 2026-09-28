import SwiftUI

private let kolommen = [GridItem(.adaptive(minimum: 104), spacing: 12)]

struct ZoekScherm: View {
    @Environment(Bibliotheek.self) private var bib
    @State private var tekst = ""
    @State private var resultaten: [Titel] = []
    @State private var bezig = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if tekst.trimmingCharacters(in: .whitespaces).isEmpty {
                    recent
                } else if resultaten.isEmpty && !bezig {
                    ContentUnavailableView.search(text: tekst)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: kolommen, spacing: 18) {
                        ForEach(resultaten) { t in
                            NavigationLink(value: t.keuze(false)) { TitelKaart(titel: t, serie: t.isSerie(false)) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.achtergrond)
            .navigationTitle("Zoeken")
            .searchable(text: $tekst, prompt: "Films en series")
            .onSubmit(of: .search) { bib.onthoudZoekopdracht(tekst) }
            .navigationDestination(for: Keuze.self) { DetailScherm(keuze: $0) }
            .task(id: tekst) {
                let q = tekst.trimmingCharacters(in: .whitespaces)
                guard !q.isEmpty else { resultaten = []; return }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                bezig = true
                let p: Pagina? = await TMDB.haal("/search/multi", ["query": q])
                guard !Task.isCancelled else { return }
                resultaten = (p?.results ?? []).filter { $0.media_type == "movie" || $0.media_type == "tv" }
                bezig = false
                if !resultaten.isEmpty { bib.onthoudZoekopdracht(q) }
            }
        }
    }

    @ViewBuilder private var recent: some View {
        if bib.zoekopdrachten.isEmpty {
            ContentUnavailableView("Zoek een film of serie",
                                   systemImage: "magnifyingglass",
                                   description: Text("Typ een titel om te beginnen."))
                .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Eerder gezocht").font(.kop(20))
                    Spacer()
                    Button("Wissen") { bib.wisZoekopdrachten() }.font(.subheadline)
                }
                .padding(.bottom, 8)
                ForEach(bib.zoekopdrachten, id: \.self) { q in
                    Button {
                        tekst = q
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                            Text(q)
                            Spacer()
                            Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .padding()
        }
    }
}

struct FavorietenScherm: View {
    @Environment(Bibliotheek.self) private var bib

    var body: some View {
        NavigationStack {
            ScrollView {
                if bib.favorieten.isEmpty {
                    ContentUnavailableView("Nog geen favorieten",
                                           systemImage: "heart",
                                           description: Text("Tik op het hartje bij een film of serie om hem hier te bewaren."))
                        .padding(.top, 80)
                } else {
                    LazyVGrid(columns: kolommen, spacing: 18) {
                        ForEach(bib.favorieten) { b in
                            NavigationLink(value: b.keuze) {
                                VStack(alignment: .leading, spacing: 6) {
                                    PosterVlak(pad: b.poster)
                                    Text(b.naam).font(.footnote.weight(.medium)).lineLimit(1)
                                    Text(b.serie ? "Serie" : "Film").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Uit favorieten", systemImage: "heart.slash", role: .destructive) {
                                    bib.wisselFavoriet(b.keuze)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color.achtergrond)
            .navigationTitle("Favorieten")
            .navigationDestination(for: Keuze.self) { DetailScherm(keuze: $0) }
        }
    }
}

struct GeschiedenisScherm: View {
    @Environment(Bibliotheek.self) private var bib
    @State private var vraagWissen = false

    var body: some View {
        NavigationStack {
            Group {
                if bib.geschiedenis.isEmpty {
                    ContentUnavailableView("Nog niets gekeken",
                                           systemImage: "clock",
                                           description: Text("Wat je kijkt, komt hier te staan."))
                } else {
                    List {
                        ForEach(bib.geschiedenis) { b in
                            HStack(spacing: 14) {
                                NavigationLink(value: b.keuze) {
                                    HStack(spacing: 14) {
                                        PosterVlak(pad: b.poster, hoek: 7).frame(width: 52)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(b.naam).font(.subheadline.weight(.medium)).lineLimit(1)
                                            Text(b.serie ? b.stand : "Film")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.goud)
                                            Text(Tijd.relatief(b.tijd))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Button {
                                    bib.speel(b.keuze, seizoen: b.seizoen, aflevering: b.aflevering)
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.footnote)
                                        .foregroundStyle(Color.achtergrond)
                                        .frame(width: 34, height: 34)
                                        .background(Color.goud, in: Circle())
                                }
                                .buttonStyle(.borderless)
                            }
                            .listRowBackground(Color.achtergrond)
                            .swipeActions {
                                Button("Verwijder", systemImage: "trash", role: .destructive) { bib.verwijder(b) }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.achtergrond)
            .navigationTitle("Geschiedenis")
            .toolbar {
                if !bib.geschiedenis.isEmpty {
                    Button("Wissen") { vraagWissen = true }
                }
            }
            .confirmationDialog("Hele geschiedenis wissen?", isPresented: $vraagWissen, titleVisibility: .visible) {
                Button("Wissen", role: .destructive) { bib.wisGeschiedenis() }
            }
            .navigationDestination(for: Keuze.self) { DetailScherm(keuze: $0) }
        }
    }
}
