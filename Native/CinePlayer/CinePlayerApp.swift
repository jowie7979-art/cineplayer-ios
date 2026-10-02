import SwiftUI
import UIKit
import SafariServices

@main
struct CinePlayerApp: App {
    @State private var bib = Bibliotheek()

    init() {
        let groot = UIFont.systemFont(ofSize: 34, weight: .bold)
        let klein = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let a = UINavigationBarAppearance()
        a.configureWithTransparentBackground()
        if let d = groot.fontDescriptor.withDesign(.serif) {
            a.largeTitleTextAttributes = [.font: UIFont(descriptor: d, size: 34)]
        }
        if let d = klein.fontDescriptor.withDesign(.serif) {
            a.titleTextAttributes = [.font: UIFont(descriptor: d, size: 17)]
        }
        let vast = a.copy()
        vast.configureWithDefaultBackground()
        vast.largeTitleTextAttributes = a.largeTitleTextAttributes
        vast.titleTextAttributes = a.titleTextAttributes
        UINavigationBar.appearance().standardAppearance = vast
        UINavigationBar.appearance().compactAppearance = vast
        UINavigationBar.appearance().scrollEdgeAppearance = a
    }

    var body: some Scene {
        WindowGroup {
            Hoofdscherm()
                .environment(bib)
                .preferredColorScheme(.dark)
                .tint(.goud)
        }
    }
}

struct Hoofdscherm: View {
    @Environment(Bibliotheek.self) private var bib

    var body: some View {
        @Bindable var bib = bib
        TabView {
            Tab("Thuis", systemImage: "play.rectangle.on.rectangle") { ThuisScherm() }
            Tab("Favorieten", systemImage: "heart") { FavorietenScherm() }
            Tab("Geschiedenis", systemImage: "clock") { GeschiedenisScherm() }
            Tab(role: .search) { ZoekScherm() }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { Voorlader.gedeeld.opwarmen(bron: bib.bron) }
        .fullScreenCover(item: $bib.speelt) { spel in
            if bib.bron.inSafari {
                SafariSpeler(adres: bib.bron.adres(spel.keuze.tmdb, serie: spel.keuze.serie,
                                                   seizoen: spel.seizoen, aflevering: spel.aflevering)) {
                    bib.speelt = nil
                }
                .ignoresSafeArea()
            } else {
                SpelerScherm(start: spel)
            }
        }
    }
}

/// Bron in Safari binnen de app (eigen knoppen, AirPlay en Klaar van Safari).
struct SafariSpeler: UIViewControllerRepresentable {
    let adres: String
    let klaar: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let cfg = SFSafariViewController.Configuration()
        cfg.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: URL(string: adres)!, configuration: cfg)
        vc.preferredBarTintColor = .black
        vc.preferredControlTintColor = UIColor(Color.goud)
        vc.dismissButtonStyle = .close
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(klaar: klaar) }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let klaar: () -> Void
        init(klaar: @escaping () -> Void) { self.klaar = klaar }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) { klaar() }
    }
}
