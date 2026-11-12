import SwiftUI

// Mirrors LaunchScreen.storyboard's layout exactly (same background color, same logo, "Bloom"
// pinned near the bottom) — the real OS launch screen can't be held open any longer by app code
// at all; it tears down the instant this app's first frame renders, regardless of any delay run
// here. This view is what actually makes the brand moment linger a bit longer: RootRouterView
// shows it for a short extra beat before revealing the real app, since there's no network call
// or other real work to wait on otherwise.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color("BloomSplashBackground")
                .ignoresSafeArea()

            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)

            VStack {
                Spacer()
                Text("Bloom")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 56)
            }
        }
    }
}

#Preview {
    SplashView()
}
