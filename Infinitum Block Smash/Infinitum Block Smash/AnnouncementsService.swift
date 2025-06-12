import Foundation

struct Announcement: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let content: String
    let date: String
    let priority: Int
    let link: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case date
        case priority
        case link
    }
}

@MainActor
class AnnouncementsService: ObservableObject {
    @Published var announcements: [Announcement] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let announcementsURL = "https://raw.githubusercontent.com/jrftw/blocksmashannouncements/main/announcements.json"
    
    func fetchAnnouncements() async {
        isLoading = true
        error = nil
        
        do {
            guard let url = URL(string: announcementsURL) else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let announcements = try decoder.decode([Announcement].self, from: data)
            
            // Sort by priority first (higher numbers first), then by date (newest first)
            self.announcements = announcements.sorted { a1, a2 in
                if a1.priority != a2.priority {
                    return a1.priority > a2.priority
                }
                return a1.date > a2.date
            }
            self.isLoading = false
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
} 