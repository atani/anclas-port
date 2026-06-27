import UserNotifications

@MainActor
enum NotificationManager {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleMatchReminders(for matches: [Match]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        let scheduled = matches.filter { $0.isAnclas && $0.status == "scheduled" }

        for match in scheduled {
            guard let kickoff = match.startDate else { continue }
            let fireDate = kickoff.addingTimeInterval(-3600)
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "⚓ まもなくキックオフ"
            var body = match.roundLabel.isEmpty ? "" : "\(match.roundLabel) "
            body += "vs \(match.opponent)"
            if let venue = match.venue { body += " / \(venue)" }
            if let ko = match.kickoff { body += " / \(ko) KO" }
            content.body = body
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: match.id, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
