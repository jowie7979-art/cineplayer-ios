import SwiftUI

@main
struct CinePlayerApp: App {
    @State private var bib = Bibliotheek()

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
        .fullScreenCover(item: $bib.speelt) { spel in
            SpelerScherm(start: spel)
        }
    }
}
