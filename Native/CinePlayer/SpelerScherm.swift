import SwiftUI

struct SpelerScherm: View {
    @Environment(Bibliotheek.self) private var bib
    @Environment(\.dismiss) private var dismiss
    @State private var huidig: Afspelen
    @State private var herlaad = 0
    @State private var sleep: CGFloat = 0
    @State private var aanraking = 0
    @State private var tvHulp = false
    @State private var gedraaid = false

    @ViewBuilder private var laadMelding: some View {
        let stand = Voorlader.gedeeld.toestand.stand
        switch stand {
        case .laden, .traag:
            VStack(spacing: 12) {
                ProgressView().tint(.white).controlSize(.large)
                Text(stand == .laden ? (Voorlader.gedeeld.toestand.duur > 0 ? "Bufferen…" : "Film laden…") : "Duurt lang. Tik op afspelen of kies een andere bron via ⋯")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(Voorlader.gedeeld.toestand.duur > 0 ? 0 : 0.55))
            .transition(.opacity)
        case .tikken:
            Text("Klaar, tik op afspelen")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.goud, in: Capsule())
                .foregroundStyle(.black)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 16)
                .transition(.opacity)
        case .leeg, .klaar, .speelt:
            EmptyView()
        }
    }

    init(start: Afspelen) { _huidig = State(initialValue: start) }

    private var adres: String {
        bib.bron.adres(huidig.keuze.tmdb, serie: huidig.keuze.serie,
                       seizoen: huidig.seizoen, aflevering: huidig.aflevering)
    }

    @Environment(\.verticalSizeClass) private var hoogte
    private var liggend: Bool { hoogte == .compact }

    var body: some View {
        // Staand: balk vast boven de speler. Liggend: alleen de film, de
        // eigen bediening heeft dan een knop terug.
        let t = Voorlader.gedeeld.toestand
        VStack(spacing: 0) {
            if !liggend { balk }
            WebSpeler(adres: adres, herlaad: herlaad)
                .ignoresSafeArea(edges: liggend ? .all : .bottom)
                .overlay {
                    if t.eigenBediening && t.duur > 0 {
                        Bediening(toestand: t, titel: huidig.keuze.naam, liggend: liggend, draai: draai)
                    }
                }
                .overlay { laadMelding.allowsHitTesting(false) }
        }
        .background(Color.black.ignoresSafeArea())
        .onDisappear { if liggend { draai(false) } }
        // Film begint: vanzelf liggend, ook met draaivergrendeling aan.
        .onChange(of: t.stand) { _, nieuw in
            guard nieuw == .speelt, !gedraaid else { return }
            gedraaid = true
            if !liggend { draai(true) }
        }
        .offset(y: sleep)
        .animation(.interactiveSpring(), value: sleep)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task {
            guard huidig.keuze.serie, huidig.seizoenen.isEmpty else { return }
            let d: Details? = await TMDB.haal("/tv/\(huidig.keuze.tmdb)")
            huidig.seizoenen = (d?.seasons ?? []).filter { $0.season_number > 0 }
        }
    }

    private var balk: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Sluiten")
            VStack(alignment: .leading, spacing: 1) {
                Text(huidig.keuze.naam)
                    .font(.kop(17))
                    .lineLimit(1)
                if huidig.keuze.serie {
                    Text("Seizoen \(huidig.seizoen) · Aflevering \(huidig.aflevering)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if let volgende = huidig.volgende {
                Button {
                    huidig.seizoen = volgende.0
                    huidig.aflevering = volgende.1
                    bib.onthoud(huidig.keuze, seizoen: volgende.0, aflevering: volgende.1)
                    aanraking += 1
                } label: {
                    Label("Volgende", systemImage: "forward.end.fill")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.goud.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.goud)
                }
                .sensoryFeedback(.impact, trigger: huidig.aflevering)
            }
            Button { tvHulp = true } label: {
                Image(systemName: "tv")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Op tv kijken")
            .alert("Op tv kijken", isPresented: $tvHulp) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Open het Bedieningspaneel, tik op Schermsynchronisatie en kies je tv. Draai daarna je iPhone en tik in de speler op volledig scherm.")
            }
            Menu {
                Picker("Bron", selection: Binding(get: { bib.bron }, set: { bib.kiesBron($0) })) {
                    ForEach(Bron.allCases) { Text($0.naam).tag($0) }
                }
                Button("Opnieuw laden", systemImage: "arrow.clockwise") { herlaad += 1; aanraking += 1 }
                Toggle("Reclame blokkeren", systemImage: "hand.raised", isOn: Binding(
                    get: { Voorlader.gedeeld.toestand.reclameBlokkeren },
                    set: { Voorlader.gedeeld.zetReclameBlokkeren($0) }))
                Toggle("Eigen bediening", systemImage: "slider.horizontal.below.rectangle", isOn: Binding(
                    get: { Voorlader.gedeeld.toestand.eigenBediening },
                    set: { Voorlader.gedeeld.zetEigenBediening($0) }))
                Toggle("iPhone-buffer", systemImage: "memorychip", isOn: Binding(
                    get: { Voorlader.gedeeld.toestand.iphoneBuffer },
                    set: { Voorlader.gedeeld.zetIphoneBuffer($0) }))
                Button(bib.isFavoriet(huidig.keuze) ? "Uit favorieten" : "Aan favorieten toevoegen",
                       systemImage: bib.isFavoriet(huidig.keuze) ? "heart.slash" : "heart") {
                    bib.wisselFavoriet(huidig.keuze)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Bron en opties")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { aanraking += 1 }
        .gesture(sluitGebaar)
    }

    private func draai(_ liggend: Bool) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: liggend ? .landscapeRight : .portrait))
    }

    private var sluitGebaar: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { w in sleep = max(0, w.translation.height) }
            .onEnded { w in
                if w.translation.height > 110 || w.predictedEndTranslation.height > 260 {
                    dismiss()
                } else {
                    sleep = 0
                }
            }
    }
}

/// Houder voor de gedeelde webview van de Voorlader: die heeft de bron vaak
/// al geladen terwijl je op het detailscherm zat.
struct WebSpeler: UIViewRepresentable {
    let adres: String
    let herlaad: Int

    final class Houder: UIView {
        var herlaad = 0
        override func layoutSubviews() {
            super.layoutSubviews()
            subviews.forEach { $0.frame = bounds }
        }
        // Pas afspelen als de speler echt in beeld staat.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { Voorlader.gedeeld.inBeeld() }
        }
    }

    func makeUIView(context: Context) -> Houder {
        let h = Houder()
        h.backgroundColor = .black
        h.herlaad = herlaad
        Voorlader.gedeeld.toon(in: h, adres: adres)
        return h
    }

    func updateUIView(_ h: Houder, context: Context) {
        let opnieuw = h.herlaad != herlaad
        h.herlaad = herlaad
        Voorlader.gedeeld.bereid(adres, opnieuw: opnieuw)
    }

    static func dismantleUIView(_ h: Houder, coordinator: ()) {
        Voorlader.gedeeld.verberg(uit: h)
    }
}