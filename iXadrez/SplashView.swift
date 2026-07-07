import SwiftUI

struct SplashView: View {
    @ObservedObject var loc = Loc.shared
    var onDismiss: () -> Void

    @State private var progress: CGFloat = 0
    private let duration: Double = 3.2

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("♚").font(Theme.sora(46)).foregroundColor(Theme.gold)
                Text(loc.t("introTitle"))
                    .font(Theme.soraExtraBold(28))
                    .foregroundColor(Theme.goldSoft)
                Text(loc.t("introText"))
                    .font(Theme.sora(14))
                    .foregroundColor(Theme.inkDim)
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text(loc.t("footerBy")).foregroundColor(Theme.ink)
                        Text("David Arsénio Martins").fontWeight(.bold).foregroundColor(Theme.ink)
                    }
                    .font(Theme.sora(14))

                    HStack(spacing: 8) {
                        Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                        Text("·").foregroundColor(Theme.inkDim)
                        Link("GitHub", destination: URL(string: "https://github.com/VidiPT89/iXadrez")!)
                    }
                    .font(Theme.sora(13))
                    .foregroundColor(Theme.goldSoft)
                }
                .padding(.top, 8)

                Button(loc.t("introSkip")) { onDismiss() }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.top, 10)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.panelBorder).frame(height: 3)
                        Capsule().fill(Theme.gold).frame(width: geo.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 8)
            }
            .padding(32)
            .frame(maxWidth: 380)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.panel).overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelBorder, lineWidth: 1)))
            .padding(24)
        }
        .onAppear {
            withAnimation(.linear(duration: duration)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { onDismiss() }
        }
    }
}
