import SwiftUI

@main
struct Infinitum_Block_SmashApp: App {
    @State private var showGame = false
    var body: some Scene {
        WindowGroup {
            if showGame {
                GameView()
            } else {
                HomeView(showGame: $showGame)
            }
        }
    }
}

struct HomeView: View {
    @Binding var showGame: Bool
    var body: some View {
        ZStack {
            Color(.systemIndigo).ignoresSafeArea()
            VStack(spacing: 40) {
                Spacer()
                Text("Infinitum Block Smash")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .shadow(radius: 8)
                Spacer()
                Button(action: { showGame = true }) {
                    Text("Play Classic")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 18)
                        .background(Color.blue)
                        .cornerRadius(16)
                        .shadow(radius: 6)
                }
                Spacer()
            }
        }
    }
} 