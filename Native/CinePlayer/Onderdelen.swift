import SwiftUI

extension Color {
    static let goud = Color(red: 0.784, green: 0.663, blue: 0.431)
    static let achtergrond = Color(red: 0.031, green: 0.031, blue: 0.063)
    static let kaart = Color(red: 0.086, green: 0.086, blue: 0.125)
}

extension Font {
    static func kop(_ grootte: CGFloat) -> Font { .system(size: grootte, weight: .semibold, design: .serif) }
}

struct Beeld: View {
    let pad: String?
    var maat = "w342"

    var body: some View {
        AsyncImage(url: TMDB.beeld(pad, maat), transaction: Transaction(animation: .easeOut(duration: 0.25))) { fase in
            if let img = fase.image {
                img.resizable().scaledToFill()
            } else {
                Rectangle().fill(Color.kaart)
            }
        }
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
                bib.wisselFavoriet(k)
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
