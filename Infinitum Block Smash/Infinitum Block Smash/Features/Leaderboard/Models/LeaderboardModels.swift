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

// MARK: - Leaderboard Error Types
enum LeaderboardError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError
    case offlineMode
    case retryLimitExceeded
    case permissionDenied
    case invalidCredential
    case updateFailed(Error)
    case loadFailed(Error)
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid leaderboard data"
        case .networkError:
            return "Network connection error"
        case .offlineMode:
            return "Currently offline"
        case .retryLimitExceeded:
            return "Too many retry attempts"
        case .permissionDenied:
            return "Permission denied"
        case .invalidCredential:
            return "Invalid credentials"
        case .updateFailed(let error):
            return "Failed to update leaderboard: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load leaderboard: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited - please try again later"
        }
    }
} 