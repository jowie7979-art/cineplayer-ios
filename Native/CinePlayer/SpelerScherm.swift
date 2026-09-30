import SwiftUI
import WebKit
import AVKit

struct SpelerScherm: View {
    @Environment(Bibliotheek.self) private var bib
    @Environment(\.dismiss) private var dismiss
    @State private var huidig: Afspelen
    @State private var herlaad = 0
    @State private var sleep: CGFloat = 0
    @State private var aanraking = 0

    init(start: Afspelen) { _huidig = State(initialValue: start) }

    private var adres: String {
        bib.bron.adres(huidig.keuze.tmdb, serie: huidig.keuze.serie,
                       seizoen: huidig.seizoen, aflevering: huidig.aflevering)
    }

    var body: some View {
        // Balk vast boven de speler: tikken op de film gaat naar de bron,
        // dus een balk die verdwijnt kwam niet meer terug.
        VStack(spacing: 0) {
            balk
            WebSpeler(adres: adres, herlaad: herlaad)
                .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.black.ignoresSafeArea())
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
            AirPlayKnop()
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.1), in: Circle())
                .accessibilityLabel("AirPlay")
            Menu {
                Picker("Bron", selection: Binding(get: { bib.bron }, set: { bib.kiesBron($0) })) {
                    ForEach(Bron.allCases) { Text($0.naam).tag($0) }
                }
                Button("Opnieuw laden", systemImage: "arrow.clockwise") { herlaad += 1; aanraking += 1 }
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

/// Systeemknop voor AirPlay: kies een tv en de video in de speler gaat erheen.
struct AirPlayKnop: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.tintColor = .white
        v.activeTintColor = UIColor(Color.goud)
        v.prioritizesVideoDevices = true
        return v
    }

    func updateUIView(_ v: AVRoutePickerView, context: Context) {}
}

/// Toont de bron in een iframe met sandbox: de bron kan het venster niet
/// overnemen en geen pop-ups openen. De basis-URL geeft de bron een referrer.
struct WebSpeler: UIViewRepresentable {
    let adres: String
    let herlaad: Int

    func makeCoordinator() -> Regelaar { Regelaar() }

    func makeUIView(context: Context) -> WKWebView {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        try? AVAudioSession.sharedInstance().setActive(true)
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.allowsPictureInPictureMediaPlayback = true
        cfg.allowsAirPlayForMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.isElementFullscreenEnabled = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        laad(web, context.coordinator)
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.adres != adres || context.coordinator.herlaad != herlaad {
            laad(web, context.coordinator)
        }
    }

    private func laad(_ web: WKWebView, _ r: Regelaar) {
        r.adres = adres
        r.herlaad = herlaad
        let bron = adres.replacingOccurrences(of: "\"", with: "")
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
        iframe{border:0;width:100%;height:100%;display:block}</style></head>
        <body><iframe src="\(bron)" referrerpolicy="origin"
        sandbox="allow-scripts allow-same-origin allow-forms allow-presentation"
        allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: Regelaar.basis)
    }

    @MainActor final class Regelaar: NSObject, WKNavigationDelegate, WKUIDelegate {
        static let basis = URL(string: "https://jowie7979-art.github.io/cineplayer-ios/")!
        var adres = ""
        var herlaad = 0

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.targetFrame?.isMainFrame ?? true,
               navigationAction.request.url?.host != Regelaar.basis.host {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            nil
        }
    }
}
