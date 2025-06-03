import SwiftUI

struct GameTopBar: View {
    @Binding var showingSettings: Bool
    @Binding var showingAchievements: Bool
    @Binding var isPaused: Bool
    var body: some View {
        HStack {
            Button(action: { isPaused = true }) {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.trailing, 8)
            Text("Infinitum Block Smash")
                .font(.title2.bold())
                .foregroundColor(.white)
            Spacer()
            HStack(spacing: 20) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                Button(action: { showingAchievements = true }) {
                    Image(systemName: "rosette")
                        .font(.title2)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
} 
