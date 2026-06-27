import SwiftUI

struct SplashView: View {
    @State private var showEmblem = false
    @State private var showText = false
    @State private var finished = false

    var body: some View {
        if finished {
            ContentView()
        } else {
            ZStack {
                Theme.navy.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image("Emblem")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                        .scaleEffect(showEmblem ? 1.0 : 0.5)
                        .opacity(showEmblem ? 1.0 : 0.0)

                    VStack(spacing: 6) {
                        Text("アンクラス Port")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                        Text("ANCLAS PORT")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.orange)
                    }
                    .opacity(showText ? 1.0 : 0.0)
                    .offset(y: showText ? 0 : 10)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    showEmblem = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
                    showText = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        finished = true
                    }
                }
            }
        }
    }
}
