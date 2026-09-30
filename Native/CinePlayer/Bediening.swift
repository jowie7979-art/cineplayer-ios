import SwiftUI

/// Eigen bediening over de film: tik = tonen/verbergen, dubbeltik links of
/// rechts = 10 seconden terug/vooruit. Verdwijnt na 3 seconden tijdens het spelen.
struct Bediening: View {
    let toestand: SpelerToestand
    let titel: String
    let liggend: Bool
    let draai: (Bool) -> Void

    @State private var zichtbaar = true
    @State private var aanraking = 0
    @State private var schuif: Double?

    private var v: Voorlader { .gedeeld }
    private var nu: Double { schuif ?? toestand.tijd }

    var body: some View {
        GeometryReader { g in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture(count: 2)
                            .onEnded { e in
                                v.spring(e.location.x < g.size.width / 2 ? -10 : 10)
                                toon()
                            }
                            .exclusively(before: TapGesture().onEnded {
                                withAnimation(.easeInOut(duration: 0.25)) { zichtbaar.toggle() }
                                aanraking += 1
                            })
                    )
                if zichtbaar { knoppen.transition(.opacity) }
            }
        }
        .task(id: "\(aanraking)|\(toestand.gepauzeerd)|\(schuif == nil)") {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !toestand.gepauzeerd, schuif == nil else { return }
            withAnimation(.easeInOut(duration: 0.35)) { zichtbaar = false }
        }
    }

    private var knoppen: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(liggend ? 0.55 : 0), .clear, .clear, .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            HStack(spacing: 48) {
                knop("gobackward.10", 24) { v.spring(-10) }
                knop(toestand.gepauzeerd ? "play.fill" : "pause.fill", 38) { v.speelPauze() }
                knop("goforward.10", 24) { v.spring(10) }
            }
            VStack(spacing: 0) {
                if liggend {
                    HStack(spacing: 12) {
                        rond("chevron.down") { draai(false) }
                        Text(titel).font(.kop(17)).lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                Spacer()
                onderbalk
            }
        }
        .foregroundStyle(.white)
    }

    private var onderbalk: some View {
        HStack(spacing: 12) {
            Text(klok(nu))
            Slider(value: Binding(get: { nu }, set: { schuif = $0 }),
                   in: 0...max(toestand.duur, 1)) { bezig in
                if !bezig, let s = schuif {
                    v.zoek(s)
                    schuif = nil
                }
            }
            .tint(.goud)
            Text("-" + klok(max(0, toestand.duur - nu)))
            if !toestand.sporen.isEmpty {
                Menu {
                    Picker("Ondertiteling", selection: Binding(get: { toestand.spoor }, set: { v.kiesSpoor($0) })) {
                        Text("Uit").tag(-1)
                        ForEach(toestand.sporen.indices, id: \.self) { i in Text(toestand.sporen[i]).tag(i) }
                    }
                } label: {
                    Image(systemName: toestand.spoor >= 0 ? "captions.bubble.fill" : "captions.bubble")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Ondertiteling")
            }
            Button { draai(!liggend) } label: {
                Image(systemName: liggend ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(liggend ? "Volledig scherm uit" : "Volledig scherm")
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 16)
        .padding(.bottom, liggend ? 12 : 20)
    }

    private func knop(_ icoon: String, _ maat: CGFloat, _ actie: @escaping () -> Void) -> some View {
        Button {
            actie()
            aanraking += 1
        } label: {
            Image(systemName: icoon)
                .font(.system(size: maat, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: maat * 2, height: maat * 2)
                .background(.black.opacity(0.25), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func rond(_ icoon: String, _ actie: @escaping () -> Void) -> some View {
        Button(action: actie) {
            Image(systemName: icoon)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func toon() {
        withAnimation(.easeInOut(duration: 0.25)) { zichtbaar = true }
        aanraking += 1
    }

    private func klok(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        let t = Int(s)
        let (u, m, sec) = (t / 3600, t / 60 % 60, t % 60)
        return u > 0 ? String(format: "%d:%02d:%02d", u, m, sec) : String(format: "%d:%02d", m, sec)
    }
}