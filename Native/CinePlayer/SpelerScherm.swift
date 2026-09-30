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
    @State private var tvHulp = false
    @State private var stand: Stand = .laden

    enum Stand: Equatable { case laden, traag, klaar, speelt }

    @ViewBuilder private var laadMelding: some View {
        switch stand {
        case .laden, .traag:
            VStack(spacing: 12) {
                ProgressView().tint(.white).controlSize(.large)
                Text(stand == .laden ? "Film laden…" : "Duurt lang. Tik op afspelen of kies een andere bron via ⋯")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.55))
            .transition(.opacity)
        case .klaar:
            Text("Klaar, tik op afspelen")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.goud, in: Capsule())
                .foregroundStyle(.black)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 16)
                .transition(.opacity)
        case .speelt:
            EmptyView()
        }
    }

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
            WebSpeler(adres: adres, herlaad: herlaad) { stand = $0 }
                .ignoresSafeArea(edges: .bottom)
                .overlay { laadMelding.allowsHitTesting(false) }
        }
        .background(Color.black.ignoresSafeArea())
        .task(id: "\(adres)|\(herlaad)") {
            stand = .laden
            try? await Task.sleep(for: .seconds(25))
            if !Task.isCancelled, stand == .laden { stand = .traag }
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

/// Toont de bron in een iframe met sandbox: de bron kan het venster niet
/// overnemen en geen pop-ups openen. De basis-URL geeft de bron een referrer.
struct WebSpeler: UIViewRepresentable {
    let adres: String
    let herlaad: Int

    var meld: (SpelerScherm.Stand) -> Void = { _ in }

    func makeCoordinator() -> Regelaar { Regelaar() }

    func makeUIView(context: Context) -> WKWebView {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        try? AVAudioSession.sharedInstance().setActive(true)
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.allowsPictureInPictureMediaPlayback = true
        // Uit: de bronnen spelen via MSE-streams die AirPlay niet kan
        // doorgeven (tv toont dan alleen een muzieknoot). Schermsynchronisatie werkt wel.
        cfg.allowsAirPlayForMediaPlayback = false
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.isElementFullscreenEnabled = true
        // Script in alle frames (ook de iframe van de bron): meldt wanneer de
        // video kan spelen en start hem dan zelf.
        cfg.userContentController.addUserScript(WKUserScript(
            source: Regelaar.volgScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        cfg.userContentController.add(context.coordinator, name: "cine")
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
        context.coordinator.meld = meld
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

    @MainActor final class Regelaar: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let basis = URL(string: "https://jowie7979-art.github.io/cineplayer-ios/")!
        var adres = ""
        var herlaad = 0
        var meld: (SpelerScherm.Stand) -> Void = { _ in }

        static let volgScript = """
        (function(){
          if (window.__cine) return; window.__cine = 1;
          function meld(s){ try { webkit.messageHandlers.cine.postMessage(s); } catch(e) {} }
          function koppel(v){
            if (v.__cine) return; v.__cine = 1;
            v.addEventListener('canplay', function(){
              if (v.paused) {
                meld('klaar');
                if (!v.__gestart) { v.__gestart = 1; var p = v.play(); if (p) p.catch(function(){}); }
              }
            });
            v.addEventListener('playing', function(){ meld('speelt'); });
            v.addEventListener('waiting', function(){ meld('laden'); });
            if (v.readyState >= 3) v.dispatchEvent(new Event('canplay'));
            else if (!v.paused) meld('speelt');
          }
          function zoek(){ document.querySelectorAll('video').forEach(koppel); }
          new MutationObserver(zoek).observe(document.documentElement, {childList:true, subtree:true});
          zoek();
        })();
        """

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            let stand: SpelerScherm.Stand? = switch message.body as? String {
                case "klaar": .klaar
                case "speelt": .speelt
                case "laden": .laden
                default: nil
            }
            if let stand { withAnimation(.easeInOut(duration: 0.25)) { meld(stand) } }
        }

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
