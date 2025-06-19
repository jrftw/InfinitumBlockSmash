import Foundation

struct LeaderboardEntry: Identifiable, Codable {
    let id: String
    let username: String
    let score: Int
    let timestamp: Date
    let level: Int?
    let time: TimeInterval?
    
    init(id: String, username: String, score: Int, timestamp: Date = Date(), level: Int? = nil, time: TimeInterval? = nil) {
        self.id = id
        self.username = username
        self.score = score
        self.timestamp = timestamp
        self.level = level
        self.time = time
    }
}

enum LeaderboardType {
    case score
    case achievement
    case timed
    
    var collectionName: String {
        switch self {
        case .score:
            return "classic_leaderboard"
        case .achievement:
            return "achievement_leaderboard"
        case .timed:
            return "classic_timed_leaderboard"
        }
    }
    
    var title: String {
        switch self {
        case .score:
            return "High Scores"
        case .achievement:
            return "Achievement Points"
        case .timed:
            return "Best Times"
        }
    }
    
    var scoreField: String {
        switch self {
        case .score:
            return "score"
        case .achievement:
            return "points"
        case .timed:
            return "time"
        }
    }
    
    var sortOrder: String {
        switch self {
        case .score, .achievement:
            return "desc"
        case .timed:
            return "asc" // Lower time is better
        }
    }
} 