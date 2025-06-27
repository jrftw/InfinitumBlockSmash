import SwiftUI
import Combine

struct LaunchLoadingView: View {
    @State private var progress: Double = 0.0
    @State private var show: Bool = false
    @State private var ellipsis: String = ""
    @AppStorage("lastTipIndex") private var tipIndex: Int = 0
    @State private var timerCancellable: Cancellable?
    @State private var ellipsisTimerCancellable: Cancellable?
    
    private let tips = [
        "Tip: You can undo your last move!",
        "Did you know? You can change themes in Settings.",
        "Pro Tip: Try to clear multiple lines at once for a high score!",
        "Fun Fact: Made in Pittsburgh, PA 🇺🇸",
        "💎 Subscribe to remove ads and unlock all themes!",
        "🎮 Get 24 hours ad-free by referring a friend and they do too!",
        "✨ Buy undo packs to fix an oopsie!",
        "🌟 Unlock exclusive themes with a subscription!",
        "🎯 Watch ads to get extra hints during gameplay!",
        "🏆 Subscribe to access all premium features!",
        "🎨 Customize your game with premium themes!",
        "⏰ Daily rewards get better with subscription!",
        "🎁 Support our app by watching ads!",
        "🔮 Unlock stuff with premium!",
        "📊 Track your stats with detailed analytics!",
        "🎁 Premium users get exclusive stuffffffff!",
        "🎪 Join our discord server for more fun!",
        "🐞 Report bugs to support@infinitumlive.com",
        "🌟 Join the test flight for Early access to new features!"
    ]
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradient()
                .ignoresSafeArea()
                .opacity(show ? 1 : 0)
                .animation(.easeIn(duration: 0.8), value: show)
            VStack(spacing: 32) {
                Spacer()
                Image("AppIcon")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: .orange.opacity(0.7), radius: 24, x: 0, y: 0)
                    .scaleEffect(show ? 1 : 0.9)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7), value: show)
                Text("Infinitum Block Smash")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .orange.opacity(0.8), radius: 12, x: 0, y: 0)
                    .scaleEffect(show ? 1 : 0.95)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7), value: show)
                HStack(spacing: 8) {
                    Text("Loading")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                    Text(ellipsis)
                        .font(.headline.bold())
                        .foregroundColor(.orange)
                        .animation(.easeInOut, value: ellipsis)
                }
                // Smoother, rounded progress bar with shadow
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 16)
                        .shadow(radius: 4)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.orange, Color.yellow]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: CGFloat(progress) * 220, height: 16)
                        .shadow(color: .orange.opacity(0.5), radius: 6, x: 0, y: 2)
                        .animation(.easeInOut(duration: 0.2), value: progress)
                }
                .frame(width: 220, height: 16)
                .padding(.vertical, 8)
                Text(AppVersion.formattedVersion)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                VStack(spacing: 4) {
                    Text("Copyright 2025  Infinitum Imagery LLC")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Text("Made by @ JrFTW in Pittsburgh PA United States")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                        Text("🇺🇸")
                            .font(.footnote)
                    }
                    // Tip/quote line
                    Text(tips[tipIndex])
                        .font(.footnote.italic())
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .opacity(show ? 1 : 0)
            .animation(.easeIn(duration: 0.8), value: show)
        }
        .onAppear {
            show = true
            // Advance to next tip on each app launch
            tipIndex = (tipIndex + 1) % tips.count
            
            // Start timers
            startTimers()
        }
        .onDisappear {
            // Clean up timers
            stopTimers()
        }
        .transition(.opacity)
    }
    
    private func startTimers() {
        // Start progress timer
        let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()
        timerCancellable = timer.sink { _ in
            if progress < 1.0 {
                progress = min(progress + 0.01, 1.0)
            }
        }
        
        // Start ellipsis timer
        let ellipsisTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        ellipsisTimerCancellable = ellipsisTimer.sink { _ in
            let dots = ["", ".", "..", "..."]
            if let idx = dots.firstIndex(of: ellipsis) {
                ellipsis = dots[(idx + 1) % dots.count]
            } else {
                ellipsis = "."
            }
            // Change tip every 4 seconds
            if progress > 0 && Int(progress * 100) % 40 == 0 {
                tipIndex = (tipIndex + 1) % tips.count
            }
        }
    }
    
    private func stopTimers() {
        timerCancellable?.cancel()
        timerCancellable = nil
        ellipsisTimerCancellable?.cancel()
        ellipsisTimerCancellable = nil
    }
}

// Animated gradient background
struct AnimatedGradient: View {
    @State private var animate = false
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [
            animate ? Color.orange : Color.purple,
            animate ? Color.yellow : Color.blue
        ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animate)
        .onAppear { animate = true }
    }
}

// Preview
struct LaunchLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchLoadingView()
    }
} 
