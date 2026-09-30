import SwiftUI
import WebKit
import AVFAudio

/// Stand van de speler, voor de laadmelding.
@Observable
final class SpelerToestand {
    enum Stand { case leeg, laden, traag, klaar, tikken, speelt }
    var stand: Stand = .leeg
    var reclameBlokkeren = !UserDefaults.standard.bool(forKey: "reclameToestaan")
    /// Eigen knoppen in plaats van die van de bron (uit te zetten in ⋯).
    var eigenBediening = !UserDefaults.standard.bool(forKey: "bronBediening")
    var ondertitels = !UserDefaults.standard.bool(forKey: "ondertitelsUit")
    var tijd: Double = 0
    var duur: Double = 0
    var gepauzeerd = true
    var sporen: [String] = []
    var spoor = -1
}

/// Eén speler voor de hele app. Laadt de bron al zodra je een titel opent,
/// zodat de film klaarstaat als je op Afspelen tikt. Tot dan staat de webview
/// onzichtbaar achter de app en houdt het script de video op pauze.
/// De bron draait in een iframe met sandbox: geen pop-ups en het venster niet
/// overnemen. De basis-URL geeft de bron een referrer.
@MainActor
final class Voorlader: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    static let gedeeld = Voorlader()
    static let basis = URL(string: "https://jowie7979-art.github.io/cineplayer-ios/")!

    let toestand = SpelerToestand()
    private let inhoud = WKUserContentController()
    private lazy var web: WKWebView = maakWeb()
    private var regels: WKContentRuleList?
    private var opgewarmd = false
    private var adres = ""
    private var actief = false
    private var gestart = false
    private var videoFrame: WKFrameInfo?
    private var traag: Task<Void, Never>?

    // MARK: van buiten

    /// Bij het openen van de app: webkit opstarten, reclamelijst klaarzetten
    /// en alvast verbinding maken met de bron.
    func opwarmen(bron: Bron) {
        guard !opgewarmd else { return }
        opgewarmd = true
        laadRegels()
        parkeer()
        let host = URL(string: bron.adres(1, serie: false, seizoen: 1, aflevering: 1))?.host ?? ""
        web.loadHTMLString("<!doctype html><html><head><link rel=\"preconnect\" href=\"https://\(host)\"></head>"
                           + "<body style=\"background:#000\"></body></html>", baseURL: Self.basis)
    }

    /// Detailscherm open: bron alvast laden, niet als de speler al open is.
    func voorladen(_ adres: String) {
        guard !actief else { return }
        bereid(adres)
    }

    /// Detailscherm dicht zonder afspelen: laden stoppen, scheelt data.
    func verlaat(_ adres: String) {
        Task {
            try? await Task.sleep(for: .seconds(1))
            guard !actief, self.adres == adres else { return }
            stop()
        }
    }

    func bereid(_ adres: String, opnieuw: Bool = false) {
        guard opnieuw || adres != self.adres else { return }
        laad(adres)
    }

    /// Speler open: webview in beeld en afspelen.
    func toon(in houder: UIView, adres: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
        try? AVAudioSession.sharedInstance().setActive(true)
        web.removeFromSuperview()
        web.frame = houder.bounds
        houder.addSubview(web)
        zetZichtbaar(true)
        actief = true
        zetScripts()
        if adres != self.adres { laad(adres) }
    }

    /// Speler staat in beeld: voorgeladen film starten of verder laten spelen.
    func inBeeld() {
        guard actief, videoFrame != nil else { return }
        speel()
    }

    /// Speler dicht: pauzeren en terug achter de app.
    func verberg(uit houder: UIView) {
        guard web.superview === houder else { return }
        actief = false
        zetScripts()
        pauzeer()
        parkeer()
    }

    func zetReclameBlokkeren(_ aan: Bool) {
        toestand.reclameBlokkeren = aan
        UserDefaults.standard.set(!aan, forKey: "reclameToestaan")
        if let regels {
            if aan { inhoud.add(regels) } else { inhoud.remove(regels) }
        }
        if !adres.isEmpty { laad(adres) }
    }

    // MARK: eigen bediening

    func zetEigenBediening(_ aan: Bool) {
        toestand.eigenBediening = aan
        UserDefaults.standard.set(!aan, forKey: "bronBediening")
        zetScripts()
        guard let frame = videoFrame else { return }
        web.evaluateJavaScript("window.__cineEigen = \(aan); window.__cineVerberg && window.__cineVerberg(\(aan)); true",
                               in: frame, in: .page, completionHandler: nil)
    }

    /// Ondertitels van de bron tonen of verbergen (de bron kiest zelf Engels).
    func zetOndertitels(_ aan: Bool) {
        toestand.ondertitels = aan
        UserDefaults.standard.set(!aan, forKey: "ondertitelsUit")
        zetScripts()
        guard let frame = videoFrame else { return }
        web.evaluateJavaScript("window.__cineOt = \(aan); window.__cineOndertitels && window.__cineOndertitels(\(aan) && window.__cineEigen); true",
                               in: frame, in: .page, completionHandler: nil)
    }

    func speelPauze() {
        toestand.gepauzeerd.toggle()
        bedien("if (v.paused) { window.__cineActief = true; await v.play(); } else { v.pause(); }")
    }

    func spring(_ s: Double) {
        toestand.tijd = max(0, min(toestand.duur, toestand.tijd + s))
        bedien("v.currentTime = Math.max(0, Math.min(v.duration - 1, v.currentTime + s));", ["s": s])
    }

    func zoek(_ t: Double) {
        toestand.tijd = t
        bedien("v.currentTime = t;", ["t": t])
    }

    func kiesSpoor(_ i: Int) {
        toestand.spoor = i
        bedien("""
        var n = 0;
        for (var k = 0; k < v.textTracks.length; k++) {
          var s = v.textTracks[k];
          if (s.kind === 'subtitles' || s.kind === 'captions') { s.mode = (n === i) ? 'showing' : 'disabled'; n++; }
        }
        """, ["i": i])
    }

    /// Voert een opdracht uit op de hoofdvideo (v) in het frame van de bron.
    private func bedien(_ js: String, _ args: [String: Any] = [:]) {
        guard let frame = videoFrame else { return }
        web.callAsyncJavaScript("var v = window.__cineVideo && window.__cineVideo(); if (!v) return false;\n" + js + "\nreturn true;",
                                arguments: args, in: frame, in: .page, completionHandler: nil)
    }

    // MARK: laden

    private func laad(_ adres: String) {
        self.adres = adres
        gestart = false
        videoFrame = nil
        toestand.tijd = 0
        toestand.duur = 0
        toestand.gepauzeerd = true
        toestand.sporen = []
        toestand.spoor = -1
        zet(.laden)
        traag?.cancel()
        traag = Task {
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled, toestand.stand == .laden else { return }
            zet(.traag)
        }
        if web.superview == nil { parkeer() }
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
        web.loadHTMLString(html, baseURL: Self.basis)
    }

    private func stop() {
        adres = ""
        videoFrame = nil
        traag?.cancel()
        zet(.leeg)
        web.loadHTMLString("<body style=\"background:#000\"></body>", baseURL: Self.basis)
    }

    private func speel() {
        guard let frame = videoFrame else { return }
        gestart = true
        web.callAsyncJavaScript(Self.speelScript, arguments: [:], in: frame, in: .page) { uitkomst in
            let mislukt: Bool
            if case .failure = uitkomst { mislukt = true } else { mislukt = false }
            Task { @MainActor in
                let v = Voorlader.gedeeld
                if mislukt, v.actief, v.toestand.stand != .speelt { v.zet(.tikken) }
            }
        }
    }

    private func pauzeer() {
        guard let frame = videoFrame else { return }
        web.evaluateJavaScript(
            "window.__cineActief = false; document.querySelectorAll('video').forEach(function(v){ v.pause(); }); true",
            in: frame, in: .page, completionHandler: nil)
    }

    private func zet(_ s: SpelerToestand.Stand) {
        guard toestand.stand != s else { return }
        withAnimation(.easeInOut(duration: 0.25)) { toestand.stand = s }
    }

    // MARK: webview

    private func maakWeb() -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController = inhoud
        cfg.allowsInlineMediaPlayback = true
        cfg.allowsPictureInPictureMediaPlayback = true
        // Uit: de bronnen spelen via MSE-streams die AirPlay niet kan
        // doorgeven (tv toont dan alleen een muzieknoot). Schermsynchronisatie werkt wel.
        cfg.allowsAirPlayForMediaPlayback = false
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.isElementFullscreenEnabled = true
        inhoud.add(self, name: "cine")
        zetScripts()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.navigationDelegate = self
        web.uiDelegate = self
        return web
    }

    /// Onzichtbaar achter de app, maar wel in het venster: zo laadt de bron
    /// op volle snelheid (buiten het venster remt webkit pagina's af).
    private func parkeer() {
        zetZichtbaar(false)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let venster = scenes.compactMap(\.keyWindow).first ?? scenes.first?.windows.first else { return }
        web.removeFromSuperview()
        web.frame = venster.bounds
        venster.insertSubview(web, at: 0)
    }

    private func zetZichtbaar(_ ja: Bool) {
        web.alpha = ja ? 1 : 0
        web.isUserInteractionEnabled = ja
        web.accessibilityElementsHidden = !ja
    }

    /// Script in alle frames, ook die van de bron. Nieuwe frames krijgen de
    /// actuele stand mee: niet actief = video direct weer op pauze.
    private func zetScripts() {
        inhoud.removeAllUserScripts()
        let vlaggen = "window.__cineActief = \(actief); window.__cineEigen = \(toestand.eigenBediening); "
            + "window.__cineOt = \(toestand.ondertitels);\n"
        inhoud.addUserScript(WKUserScript(source: vlaggen + Self.volgScript,
                                          injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }

    private func laadRegels() {
        let lijst = Self.reclame.map { domein in
            ["trigger": ["url-filter": "^[^:]+://+([^:/]+\\.)?" + domein.replacingOccurrences(of: ".", with: "\\.") + "[:/]"],
             "action": ["type": "block"]]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: lijst),
              let json = String(data: data, encoding: .utf8) else { return }
        let opslag: WKContentRuleListStore? = WKContentRuleListStore.default()
        opslag?.compileContentRuleList(forIdentifier: "cine-reclame", encodedContentRuleList: json) { klaar, _ in
            guard let klaar else { return }
            Task { @MainActor in
                let v = Voorlader.gedeeld
                v.regels = klaar
                if v.toestand.reclameBlokkeren { v.inhoud.add(klaar) }
            }
        }
    }

    // MARK: berichten van het script

    func userContentController(_ c: WKUserContentController, didReceive bericht: WKScriptMessage) {
        guard !adres.isEmpty else { return }
        if let d = bericht.body as? [String: Any] {
            switch d["soort"] as? String {
            case "tijd":
                videoFrame = bericht.frameInfo
                toestand.tijd = d["t"] as? Double ?? 0
                toestand.duur = d["d"] as? Double ?? 0
                toestand.gepauzeerd = d["p"] as? Bool ?? true
            case "sporen":
                toestand.sporen = d["l"] as? [String] ?? []
                toestand.spoor = d["a"] as? Int ?? -1
            default:
                break
            }
            return
        }
        guard let s = bericht.body as? String else { return }
        switch s {
        case "klaar":
            videoFrame = bericht.frameInfo
            if actief && !gestart && web.window != nil && web.alpha > 0 {
                speel()
            } else if toestand.stand != .tikken {
                zet(.klaar)
            }
        case "speelt":
            videoFrame = bericht.frameInfo
            if actief { zet(.speelt) } else { pauzeer() }
        case "laden":
            if toestand.stand != .tikken { zet(.laden) }
        default:
            break
        }
    }

    // MARK: navigatie

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame?.isMainFrame ?? true,
           navigationAction.request.url?.host != Self.basis.host {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        nil
    }

    // MARK: scripts

    /// Luistert in de vangfase op het document, dus ook naar video's die de
    /// bron later toevoegt.
    static let volgScript = """
    (function(){
      if (window.__cine) return; window.__cine = 1;
      function meld(s){ try { webkit.messageHandlers.cine.postMessage(s); } catch(e) {} }
      function video(e){ return e.target instanceof HTMLVideoElement; }
      document.addEventListener('play', function(e){
        if (video(e) && !window.__cineActief) e.target.pause();
      }, true);
      document.addEventListener('canplay', function(e){
        if (video(e) && e.target.paused) meld('klaar');
      }, true);
      document.addEventListener('playing', function(e){ if (video(e)) meld('speelt'); }, true);
      document.addEventListener('waiting', function(e){ if (video(e)) meld('laden'); }, true);

      // Ondertitels altijd Engels: MoviesAPI kiest Engels zolang er geen
      // andere keuze (of "uit") is opgeslagen.
      try {
        var k = 'vp_subtitle_lang', w = localStorage.getItem(k);
        if (w && !/^en/i.test(w)) localStorage.removeItem(k);
      } catch(e) {}

      function stijl(id, aan, css){
        var s = document.getElementById(id);
        if (aan && !s) {
          s = document.createElement('style'); s.id = id; s.textContent = css;
          (document.head || document.documentElement).appendChild(s);
        }
        if (!aan && s) s.remove();
      }
      // Eigen bediening: alles van de bron onzichtbaar behalve de video
      // en (als ze aan staan) de ondertitels.
      window.__cineVerberg = function(aan){
        stijl('__cine_stijl', aan, 'html body *{visibility:hidden!important}html body video{visibility:visible!important}');
        window.__cineOndertitels(aan && window.__cineOt);
      };
      window.__cineOndertitels = function(aan){
        var ot = 'html body [class*="captions" i]:not(button):not([class*="button" i])';
        stijl('__cine_ot', aan, ot + ',' + ot + ' *,html body [data-part="captions"],html body [data-part="captions"] *'
          + '{visibility:visible!important}');
      };
      // Hoofdvideo = de langste (reclamefilmpjes zijn kort).
      window.__cineVideo = function(){
        var l = Array.prototype.slice.call(document.querySelectorAll('video'));
        l.sort(function(a, b){ return (b.duration || 0) - (a.duration || 0); });
        return l[0];
      };
      var laatst = 0;
      function tijd(e){
        var v = e.target;
        if (!video(e) || !(v.duration > 60)) return;
        if (e.type === 'timeupdate') { var nu = Date.now(); if (nu - laatst < 400) return; laatst = nu; }
        if (window.__cineEigen) window.__cineVerberg(true);
        meld({soort: 'tijd', t: v.currentTime, d: v.duration, p: v.paused});
      }
      ['timeupdate', 'durationchange', 'loadedmetadata', 'play', 'pause', 'seeked'].forEach(function(n){
        document.addEventListener(n, tijd, true);
      });
      function sporen(){
        var v = window.__cineVideo(); if (!v) return;
        var l = [], a = -1;
        for (var i = 0; i < v.textTracks.length; i++) {
          var s = v.textTracks[i];
          if (s.kind === 'subtitles' || s.kind === 'captions') {
            if (s.mode === 'showing') a = l.length;
            l.push(s.label || s.language || ('Spoor ' + (l.length + 1)));
          }
        }
        meld({soort: 'sporen', l: l, a: a});
      }
      document.addEventListener('loadedmetadata', function(e){
        if (!video(e)) return;
        sporen();
        e.target.textTracks.addEventListener('addtrack', sporen);
        e.target.textTracks.addEventListener('change', sporen);
      }, true);
    })();
    """

    static let speelScript = """
    window.__cineActief = true;
    var lijst = Array.prototype.slice.call(document.querySelectorAll('video'));
    lijst.sort(function(a, b){ return b.readyState - a.readyState; });
    if (!lijst.length) return false;
    await lijst[0].play();
    return true;
    """

    /// Reclame- en volgdiensten die de bronnen inladen: blokkeren scheelt
    /// veel laadtijd. Uit te zetten in de speler (⋯) als een bron dan niet werkt.
    static let reclame = [
        "doubleclick.net", "googlesyndication.com", "googletagservices.com", "googletagmanager.com",
        "google-analytics.com", "googleadservices.com", "adservice.google.com", "amazon-adsystem.com",
        "adnxs.com", "criteo.com", "criteo.net", "taboola.com", "outbrain.com", "mgid.com", "adskeeper.com",
        "popads.net", "popcash.net", "propellerads.com", "propellerclick.com", "onclickads.net", "onclkds.com",
        "monetag.com", "adsterra.com", "highperformanceformat.com", "profitablegatecpm.com",
        "effectivegatecpm.com", "exoclick.com", "exosrv.com", "exdynsrv.com", "magsrv.com", "juicyads.com",
        "hilltopads.net", "hilltopads.com", "clickadu.com", "adcash.com", "acscdn.com", "a-ads.com",
        "galaksion.com", "tsyndicate.com", "trafficstars.com", "realsrv.com", "pubmatic.com",
        "rubiconproject.com", "openx.net", "casalemedia.com", "smartadserver.com", "histats.com",
        "statcounter.com", "mc.yandex.ru", "mc.yandex.com", "hotjar.com", "facebook.net",
        "scorecardresearch.com", "quantserve.com", "cloudflareinsights.com", "dtscout.com", "dtscdn.com",
    ]
}
