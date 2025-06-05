import SwiftUI

struct GameRulesView: View {
    let gameMode: String
    @Environment(\.dismiss) var dismiss
    
    private var rules: [(String, String)] {
        [
            ("Basic Rules", "Place blocks on the grid to create matches and clear lines. Each block must touch at least one other block of the same color."),
            ("Scoring", """
                • 1 point for each block that touches another block
                • 2x bonus multiplier for touching 3 or more blocks
                • 100 points for clearing a row or column
                • 500 bonus points for creating a group of 10 or more blocks
                • Chain bonuses for multiple clears
                • 500 points for diagonal patterns (both / and \\)
                • 1000 points for X pattern
                • 1000 points for perfect level (no mistakes)
                """),
            ("Level Progression", "Complete levels by reaching the score threshold. Each level introduces new shapes and challenges."),
            ("Tips", "Plan your moves carefully to create large groups and special patterns for maximum points!")
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Game Mode Header
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text(gameMode)
                        .font(.title)
                        .bold()
                }
                .padding(.bottom)
                
                // Basic Rules
                Group {
                    RuleSection(title: "Basic Rules", icon: "info.circle.fill") {
                        RuleItem(icon: "hand.point.up.left.fill", text: "Drag shapes from the tray onto the grid")
                        RuleItem(icon: "cube.fill", text: "Shapes come in various sizes and rotations")
                        RuleItem(icon: "arrow.up.right.square.fill", text: "Level up by reaching the required score")
                        RuleItem(icon: "xmark.octagon.fill", text: "Game over if no shapes can be placed")
                        RuleItem(icon: "tray.fill", text: "Always have 3 shapes available in your tray")
                    }
                }
                
                // Scoring System
                Group {
                    RuleSection(title: "Scoring System", icon: "star.fill") {
                        RuleItem(icon: "1.circle.fill", text: "1 point for each block that touches another block")
                        RuleItem(icon: "2.circle.fill", text: "2x bonus multiplier for touching 3 or more blocks")
                        RuleItem(icon: "line.horizontal.3.decrease.circle.fill", text: "100 points for clearing a row or column")
                        RuleItem(icon: "paintpalette.fill", text: "500 bonus points for clearing a row/column of the same color")
                        RuleItem(icon: "sparkles.fill", text: "200 points for creating a group of 10 or more blocks")
                        RuleItem(icon: "arrow.triangle.2.circlepath", text: "Chain bonuses for multiple clears")
                        RuleItem(icon: "checkmark.seal.fill", text: "Perfect level bonus for clearing without mistakes")
                        RuleItem(icon: "xmark", text: "1000 bonus points for creating an X pattern with same color")
                        RuleItem(icon: "slash", text: "500 bonus points for creating a diagonal pattern with same color")
                    }
                }
                
                // Level Progression
                Group {
                    RuleSection(title: "Level Progression", icon: "chart.line.uptrend.xyaxis") {
                        RuleItem(icon: "1.square.fill", text: "Level 1-5: 1000 points per level")
                        RuleItem(icon: "2.square.fill", text: "Level 6-10: 2000 points per level")
                        RuleItem(icon: "3.square.fill", text: "Level 11-50: 3000 points per level")
                        RuleItem(icon: "4.square.fill", text: "Level 51+: 5000 points per level")
                        RuleItem(icon: "plus.circle.fill", text: "New shapes unlock as you progress")
                        RuleItem(icon: "calendar", text: "Track consecutive days played")
                    }
                }
                
                // Special Features
                Group {
                    RuleSection(title: "Special Features", icon: "sparkles") {
                        RuleItem(icon: "arrow.uturn.left.circle.fill", text: "Undo your last move (limited uses)")
                        RuleItem(icon: "pause.circle.fill", text: "Pause the game anytime")
                        RuleItem(icon: "trophy.fill", text: "Track high scores and achievements")
                        RuleItem(icon: "person.2.fill", text: "Compete on global leaderboards")
                        RuleItem(icon: "chart.bar.fill", text: "Track statistics: blocks placed, lines cleared")
                        RuleItem(icon: "star.circle.fill", text: "Earn achievements for milestones")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Game Rules")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RuleSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.leading)
        }
        .padding(.vertical, 8)
    }
}

struct RuleItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationView {
        GameRulesView(gameMode: "Classic")
    }
} 