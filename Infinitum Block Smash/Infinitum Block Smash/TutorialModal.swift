import SwiftUI

struct TutorialModal: View {
    @Binding var showingTutorial: Bool
    @Binding var showTutorial: Bool
    @State private var step = 0
    @State private var isAnimating = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    
    private let steps: [(String, String, String?, String?)] = [
        ("Welcome to Infinitum Block Smash!", "Get ready to stack and smash blocks for high scores.", "star.fill", nil),
        ("Drag Shapes", "Drag shapes from the tray onto the grid. Each shape must touch at least one other block of the same color.", "hand.point.up.left.fill", "Try to create large groups for bonus points!"),
        ("Clear Lines", "Fill an entire row or column to clear it and earn points. The more blocks you clear at once, the more points you earn!", "line.horizontal.3.decrease.circle", "Look for opportunities to clear multiple lines at once!"),
        ("Special Patterns", "Create special patterns like diagonals (/) or X shapes for bonus points. These can give you up to 1000 points!", "sparkles", "Watch for opportunities to create these patterns!"),
        ("Level Up", "The game gets harder as you level up, with more complex shapes and faster gameplay. Each level requires more points to complete.", "arrow.up.right.square", "Try to beat your high score!"),
        ("Power-ups", "Use power-ups like hints and undos strategically. You get 3 hints per game, so use them wisely!", "wand.and.stars", "Power-ups can help you out of tough situations!"),
        ("Game Over", "The game ends when no more moves are possible. Try to last as long as possible and achieve a high score!", "xmark.octagon", "Don't worry, you can always try again!"),
        ("Achievements", "Complete challenges to unlock achievements and track your progress. Some achievements give special rewards!", "star.fill", "Check your achievements in the menu!")
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == step ? 1.2 : 1.0)
                        .animation(.spring(), value: step)
                }
            }
            .padding(.top)
            
            Spacer()
            
            // Main content
            VStack(spacing: 24) {
                if let icon = steps[step].2 {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.accentColor)
                        .modifier(IconAnimationModifier(isAnimating: isAnimating))
                }
                
                Text(steps[step].0)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .transition(.slide)
                
                Text(steps[step].1)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
                
                if let tip = steps[step].3 {
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: step)
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if step > 0 {
                    Button(action: {
                        withHapticFeedback {
                            step -= 1
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                if step < steps.count - 1 {
                    Button(action: {
                        withHapticFeedback {
                            step += 1
                        }
                    }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    Button(action: {
                        withHapticFeedback {
                            showTutorial = false
                            showingTutorial = false
                        }
                    }) {
                        HStack {
                            Text("Done")
                            Image(systemName: "checkmark")
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            
            Button(action: {
                withHapticFeedback {
                    showTutorial = false
                    showingTutorial = false
                }
            }) {
                Text("Skip Tutorial")
                    .foregroundColor(.red)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(BlurView(style: .systemUltraThinMaterialDark))
        .cornerRadius(24)
        .padding(32)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tutorial Step \(step + 1) of \(steps.count)")
        .accessibilityHint(steps[step].1)
    }
    
    private func withHapticFeedback(action: () -> Void) {
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        action()
    }
}

// Custom modifier for icon animation that works across iOS versions
struct IconAnimationModifier: ViewModifier {
    let isAnimating: Bool
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .symbolEffect(.bounce, value: isAnimating)
        } else {
            content
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
    }
}

#Preview {
    TutorialModal(
        showingTutorial: .constant(true),
        showTutorial: .constant(true)
    )
} 