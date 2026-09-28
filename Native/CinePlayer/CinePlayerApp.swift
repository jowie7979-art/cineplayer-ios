import SwiftUI
import UIKit

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
        .fullScreenCover(item: $bib.speelt) { spel in
            SpelerScherm(start: spel)
        }
    }
}
