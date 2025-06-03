import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    let tutorialSteps = [
        TutorialStep(
            title: "Welcome to Infinitum Block Smash!",
            description: "Let's learn how to play this exciting puzzle game.",
            imageName: "gamecontroller"
        ),
        TutorialStep(
            title: "Place Blocks",
            description: "Drag blocks from the tray to place them on the grid. Match colors and shapes to score points!",
            imageName: "square.grid.3x3.fill"
        ),
        TutorialStep(
            title: "Clear Lines",
            description: "Complete horizontal or vertical lines to clear them and earn points.",
            imageName: "arrow.up.and.down.and.arrow.left.and.right"
        ),
        TutorialStep(
            title: "Level Up",
            description: "As you progress, new shapes and colors will be introduced. Can you master them all?",
            imageName: "star.fill"
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentStep) {
                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                    TutorialStepView(step: tutorialSteps[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            Button(action: {
                if currentStep < tutorialSteps.count - 1 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    dismiss()
                }
            }) {
                Text(currentStep < tutorialSteps.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct TutorialStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
}

struct TutorialStepView: View {
    let step: TutorialStep
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: step.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text(step.title)
                .font(.title)
                .bold()
            
            Text(step.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
} 