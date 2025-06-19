import SwiftUI

struct ClassicTimedRulesView: View {
    @Environment(\.dismiss) var dismiss
    
    private var rules: [(String, String)] {
        [
            ("Basic Rules", "Place blocks on the grid to create matches and clear lines. Each block must touch at least one other block of the same color."),
            ("Time Limit", """
                • Each level has a time limit that must be completed within
                • Time limits increase with level difficulty
                • Bonus time is awarded for quick completions
                • Time remaining is converted to bonus points at level completion
                """),
            ("Scoring", """
                • 1 point for each block that touches another block
                • 2x bonus multiplier for touching 3 or more blocks
                • 100 points for clearing a row or column
                • 200 bonus points for clearing a row/column of the same color
                • Chain bonuses for multiple clears
                • 300 points for diagonal patterns (both / and \\)
                • 250 points for X pattern
                • 1000 points for perfect level (no mistakes)
                • Time bonus: 10 points per second remaining
                """),
            ("Level Progression", "Complete levels by reaching the score threshold within the time limit. Each level introduces new shapes and challenges."),
            ("Tips", "Plan your moves carefully and work quickly to maximize your score and time bonus!")
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Game Mode Header
                HStack {
                    Image(systemName: "timer")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("Classic Timed")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Rules Content
                ForEach(rules, id: \.0) { rule in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(rule.0)
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text(rule.1)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
} 