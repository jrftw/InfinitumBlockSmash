import SwiftUI

struct ContentView: View {
    @State private var showingGame = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Infinitum Block Smash")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                Button(action: { showingGame = true }) {
                    Text("Play Classic")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(Color.blue)
                        .cornerRadius(15)
                }
            }
            .padding()
            .fullScreenCover(isPresented: $showingGame) {
                GameView()
            }
        }
    }
}

#Preview {
    ContentView()
} 