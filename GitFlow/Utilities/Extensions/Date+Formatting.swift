import Foundation

extension Date {
    /// Returns a relative time description (e.g., "2 hours ago", "yesterday").
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Returns a short relative time description (e.g., "2h ago", "1d ago").
    var shortRelativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Returns a formatted date string for Git log display.
    var gitLogFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Returns an ISO 8601 formatted string.
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }

    /// Returns a human-friendly description combining date and relative time.
    var humanReadable: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            return "Today, \(timeOnly)"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday, \(timeOnly)"
        } else if let daysAgo = calendar.dateComponents([.day], from: self, to: now).day,
                  daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, h:mm a"
            return formatter.string(from: self)
        } else {
            return gitLogFormat
        }
    }

    /// Returns just the time portion.
    private var timeOnly: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
