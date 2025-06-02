import SwiftUI

struct ScoreAnimationView: View {
    let points: Int
    let position: CGPoint
    @State private var opacity: Double = 1.0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        Text("+\(points)")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(points >= 500 ? .yellow : .white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .opacity(opacity)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    offset = -50
                    opacity = 0
                }
            }
            .position(position)
    }
}

struct ScoreAnimationContainer: View {
    @State private var animations: [(id: UUID, points: Int, position: CGPoint)] = []
    
    func addAnimation(points: Int, at position: CGPoint) {
        let id = UUID()
        animations.append((id: id, points: points, position: position))
        
        // Remove animation after it completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            animations.removeAll { $0.id == id }
        }
    }
    
    var body: some View {
        ZStack {
            ForEach(animations, id: \.id) { animation in
                ScoreAnimationView(points: animation.points, position: animation.position)
            }
        }
    }
} 