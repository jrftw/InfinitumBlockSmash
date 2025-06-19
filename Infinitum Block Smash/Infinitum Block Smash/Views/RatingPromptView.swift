import SwiftUI
import StoreKit

struct RatingPromptView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Enjoying the Game?")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("If you're having fun, please take a moment to rate Infinitum Block Smash. Your feedback helps us improve!")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Maybe Later")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Rate Now")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }
} 