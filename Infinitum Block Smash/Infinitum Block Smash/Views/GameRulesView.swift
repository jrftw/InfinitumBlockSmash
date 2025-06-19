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
                • 200 bonus points for clearing a row/column of the same color
                • Chain bonuses for multiple clears
                • 300 bonus points for creating a diagonal pattern with same color
                • 250 bonus points for creating an X pattern with same color
                • Perfect level bonus for clearing without mistakes
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
                        RuleItem(icon: "paintpalette.fill", text: "200 bonus points for clearing a row/column of the same color")
                        RuleItem(icon: "sparkles.fill", text: "Chain bonuses for multiple clears")
                        RuleItem(icon: "arrow.triangle.2.circlepath", text: "300 bonus points for creating a diagonal pattern with same color")
                        RuleItem(icon: "checkmark.seal.fill", text: "Perfect level bonus for clearing without mistakes")
                        RuleItem(icon: "xmark", text: "250 bonus points for creating an X pattern with same color")
                        RuleItem(icon: "slash", text: "300 bonus points for creating a diagonal pattern with same color")
                    }
                }
                
                // Level Progression
                Group {
                    RuleSection(title: "Level Progression", icon: "chart.line.uptrend.xyaxis") {
                        RuleItem(icon: "1.square.fill", text: "Level 1: 1,000 total points")
                        RuleItem(icon: "2.square.fill", text: "Level 2: 2,100 total points")
                        RuleItem(icon: "3.square.fill", text: "Level 3: 3,300 total points")
                        RuleItem(icon: "4.square.fill", text: "Level 4: 4,600 total points")
                        RuleItem(icon: "5.square.fill", text: "Level 5: 6,000 total points")
                        RuleItem(icon: "10.square.fill", text: "Level 10: 15,250 total points")
                        RuleItem(icon: "25.square.fill", text: "Level 25: 51,500 total points")
                        RuleItem(icon: "50.square.fill", text: "Level 50: 113,500 total points")
                        RuleItem(icon: "100.square.fill", text: "Level 100: 263,500 total points")
                        RuleItem(icon: "plus.circle.fill", text: "Score accumulates throughout the entire game")
                        RuleItem(icon: "calendar", text: "Track consecutive days played")
                    }
                }
                
                // Special Level Mechanics
                Group {
                    RuleSection(title: "Special Level Mechanics", icon: "sparkles") {
                        RuleItem(icon: "60.circle.fill", text: "Level 60+: 1 random shape spawns on the board")
                        RuleItem(icon: "75.circle.fill", text: "Level 75+: 2 random shapes spawn on the board")
                        RuleItem(icon: "100.circle.fill", text: "Level 100+: 3 random shapes spawn + 10,000 points needed")
                        RuleItem(icon: "150.circle.fill", text: "Level 150+: 4 random shapes spawn on the board")
                        RuleItem(icon: "350.circle.fill", text: "Level 350+: All 3 shapes must fit before getting new ones")
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