import Foundation

extension DateFormatter {
    static func relativeTimeString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfMonth, .month, .year], from: date, to: now)
        
        if let year = components.year, year > 0 {
            return String(format: NSLocalizedString("%d years ago", comment: "Years ago format"), year)
        }
        
        if let month = components.month, month > 0 {
            return String(format: NSLocalizedString("%d months ago", comment: "Months ago format"), month)
        }
        
        if let week = components.weekOfMonth, week > 0 {
            return String(format: NSLocalizedString("%d weeks ago", comment: "Weeks ago format"), week)
        }
        
        if let day = components.day, day > 0 {
            if day == 1 {
                return NSLocalizedString("Yesterday", comment: "Yesterday")
            }
            return String(format: NSLocalizedString("%d days ago", comment: "Days ago format"), day)
        }
        
        if let hour = components.hour, hour > 0 {
            return String(format: NSLocalizedString("%d hours ago", comment: "Hours ago format"), hour)
        }
        
        if let minute = components.minute, minute > 0 {
            return String(format: NSLocalizedString("%d minutes ago", comment: "Minutes ago format"), minute)
        }
        
        return NSLocalizedString("Just Now", comment: "Just now")
    }
    
    static func relativeDateString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return NSLocalizedString("Today", comment: "Today")
        }
        
        if calendar.isDateInYesterday(date) {
            return NSLocalizedString("Yesterday", comment: "Yesterday")
        }
        
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        if date >= weekAgo {
            return NSLocalizedString("Last Week", comment: "Last week")
        }
        
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        if date >= monthAgo {
            return NSLocalizedString("Last Month", comment: "Last month")
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
} 