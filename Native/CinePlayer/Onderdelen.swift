import SwiftUI
import UIKit

extension Color {
    static let goud = Color(red: 0.784, green: 0.663, blue: 0.431)
    static let achtergrond = Color(red: 0.031, green: 0.031, blue: 0.063)
    static let kaart = Color(red: 0.086, green: 0.086, blue: 0.125)
}

extension Font {
    static func kop(_ grootte: CGFloat) -> Font { .system(size: grootte, weight: .semibold, design: .serif) }
}

@MainActor
final class BeeldCache {
    static let shared = BeeldCache()
    private let geheugen = NSCache<NSURL, UIImage>()
    private var bezig: [URL: Task<UIImage?, Never>] = [:]
    private let sessie: URLSession = {
        let c = URLSessionConfiguration.default
        c.urlCache = URLCache(memoryCapacity: 60_000_000, diskCapacity: 400_000_000)
        c.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: c)
    }()

    init() { geheugen.countLimit = 400 }

    func direct(_ url: URL) -> UIImage? { geheugen.object(forKey: url as NSURL) }

    func laad(_ url: URL) async -> UIImage? {
        if let i = direct(url) { return i }
        if let t = bezig[url] { return await t.value }
        let sessie = self.sessie
        let t = Task<UIImage?, Never> {
            guard let antwoord = try? await sessie.data(from: url) else { return nil }
            let data = antwoord.0
            return await Task.detached(priority: .userInitiated) {
                UIImage(data: data)?.preparingForDisplay()
            }.value
        }
        bezig[url] = t
        let img = await t.value
        bezig[url] = nil
        if let img { geheugen.setObject(img, forKey: url as NSURL) }
        return img
    }
}

struct Beeld: View {
    let pad: String?
    var maat = "w342"
    @State private var img: UIImage?

    init(pad: String?, maat: String = "w342") {
        self.pad = pad
        self.maat = maat
        if let url = TMDB.beeld(pad, maat) { _img = State(initialValue: BeeldCache.shared.direct(url)) }
    }

    var body: some View {
        let url = TMDB.beeld(pad, maat)
        ZStack {
            Rectangle().fill(Color.kaart)
            if let img {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .task(id: url) {
            guard let url else { img = nil; return }
            if let d = BeeldCache.shared.direct(url) { img = d; return }
            let nieuw = await BeeldCache.shared.laad(url)
            withAnimation(.easeOut(duration: 0.3)) { img = nieuw }
        }
    }
}

struct Skelet: View {
    var verhouding: CGFloat = 2 / 3
    @State private var puls = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.kaart)
            .aspectRatio(verhouding, contentMode: .fit)
            .opacity(puls ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: puls)
            .onAppear { puls = true }
            .accessibilityHidden(true)
    }
}

/// Brede kaart voor Verder kijken: tik speelt direct af.
struct VerderKaart: View {
    let bewaard: Bewaard

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Color.kaart
                .frame(width: 236, height: 133)
                .overlay { Beeld(pad: bewaard.backdrop ?? bewaard.poster, maat: "w780") }
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.achtergrond)
                            .frame(width: 24, height: 24)
                            .background(Color.goud, in: Circle())
                        Text(bewaard.serie ? bewaard.stand : "Verder kijken")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
                }
            Text(bewaard.naam)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .frame(width: 236, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bewaard.naam), \(bewaard.serie ? bewaard.stand : "film"), verder kijken")
    }
}

/// Poster in 2:3 met afgeronde hoeken.
struct PosterVlak: View {
    let pad: String?
    var hoek: CGFloat = 10

    var body: some View {
        Color.kaart
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { Beeld(pad: pad) }
            .clipShape(RoundedRectangle(cornerRadius: hoek, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: hoek, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
            }
    }
}

struct TitelKaart: View {
    @Environment(Bibliotheek.self) private var bib
    let titel: Titel
    let serie: Bool

    var body: some View {
        let k = titel.keuze(serie)
        VStack(alignment: .leading, spacing: 6) {
            PosterVlak(pad: titel.poster_path)
                .overlay(alignment: .topTrailing) {
                    if let v = titel.vote_average, v > 0 {
                        Text(v, format: .number.precision(.fractionLength(1)))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.goud)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.65), in: Capsule())
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if bib.isFavoriet(k) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .transition(.scale.combined(with: .opacity))
                            .foregroundStyle(.red)
                            .padding(6)
                            .background(.black.opacity(0.6), in: Circle())
                            .padding(6)
                    }
                }
            Text(titel.naam)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
            Text(titel.jaar.isEmpty ? " " : titel.jaar)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(bib.isFavoriet(k) ? "Uit favorieten" : "Aan favorieten toevoegen",
                   systemImage: bib.isFavoriet(k) ? "heart.slash" : "heart") {
                withAnimation(.spring(duration: 0.35)) { bib.wisselFavoriet(k) }
            }
        }
    }
}

struct BewaardKaart: View {
    let bewaard: Bewaard
    var toonStand = false
    var breedte: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PosterVlak(pad: bewaard.poster, hoek: 9)
                .overlay(alignment: .bottomLeading) {
                    if toonStand && bewaard.serie {
                        Text(bewaard.stand)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.goud)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 5))
                            .padding(6)
                    }
                }
            Text(bewaard.naam)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(width: breedte)
    }
}

struct Rij<Inhoud: View>: View {
    let titel: String
    @ViewBuilder let inhoud: Inhoud

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel)
                .font(.kop(20))
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) { inhoud }
                    .padding(.horizontal)
            }
        }
    }
}

struct Keuzechip: View {
    let tekst: String
    let actief: Bool
    let actie: () -> Void

    var body: some View {
        Button(action: actie) {
            Text(tekst)
                .font(.subheadline.weight(actief ? .semibold : .regular))
                .foregroundStyle(actief ? Color.achtergrond : .primary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(actief ? Color.goud : Color.kaart, in: Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: actief)
    }
}

enum Tijd {
    static func relatief(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: .now)
    }
}
