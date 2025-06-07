import Foundation

struct LeaderboardEntry: Identifiable, Codable {
    let id: String
    let username: String
    let score: Int
    let timestamp: Date
    
    init(id: String, username: String, score: Int, timestamp: Date = Date()) {
        self.id = id
        self.username = username
        self.score = score
        self.timestamp = timestamp
    }
}

enum LeaderboardType {
    case score
    case achievement
    
    var collectionName: String {
        switch self {
        case .score:
            return "classic_leaderboard"
        case .achievement:
            return "achievement_leaderboard"
        }
    }
    
    var title: String {
        switch self {
        case .score:
            return "High Scores"
        case .achievement:
            return "Achievement Points"
        }
    }
    
    var scoreField: String {
        switch self {
        case .score:
            return "score"
        case .achievement:
            return "points"
        }
    }
} 