import SwiftUI

struct GameModeSelectionView: View {
    var onClassic: () -> Void
    var onClassicTimed: () -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.2, blue: 0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal)
                
                Text("Select Game Mode")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                
                VStack(spacing: 20) {
                    Button(action: onClassic) {
                        GameModeButton(
                            title: "Classic",
                            description: "Place blocks and create matches at your own pace",
                            icon: "gamecontroller.fill",
                            color: .blue
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onClassicTimed) {
                        GameModeButton(
                            title: "Classic Timed",
                            description: "Race against the clock to achieve high scores",
                            icon: "timer",
                            color: .orange
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    ZStack(alignment: .leading) {
                        GameModeButton(
                            title: "Countdown Quest",
                            description: "Complete challenges before time runs out",
                            icon: "hourglass",
                            color: .purple
                        )
                        .opacity(0.5)
                        
                        HStack {
                            Spacer()
                            Text("Coming Soon")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.7))
                                .cornerRadius(8)
                                .padding(.trailing, 24)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
        }
    }
} 