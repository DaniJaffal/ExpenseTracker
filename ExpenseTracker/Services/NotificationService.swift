//
//  NotificationService.swift
//  ExpenseTracker
//
//  Local notifications for subscription renewals and expected expense due dates.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Asks the user for notification permission. Idempotent — returns current
    /// status even if already requested.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Subscription

    private func subscriptionIdentifier(_ sub: Subscription) -> String {
        "subscription-\(sub.id.uuidString)"
    }

    func scheduleNotification(for sub: Subscription) async {
        let id = subscriptionIdentifier(sub)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard sub.notificationsEnabled, sub.isActive else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let leadSeconds = TimeInterval(max(0, sub.notificationLeadDays) * 86_400)
        let fireDate = sub.nextRenewalDate.addingTimeInterval(-leadSeconds)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Subscription renewing soon"
        let leadText = sub.notificationLeadDays == 0
            ? "today"
            : "in \(sub.notificationLeadDays) day\(sub.notificationLeadDays == 1 ? "" : "s")"
        content.body = "\(sub.name) renews \(leadText)."
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do { try await center.add(request) } catch {
            print("NotificationService: failed to schedule subscription notification: \(error)")
        }
    }

    func cancelNotification(for sub: Subscription) {
        center.removePendingNotificationRequests(withIdentifiers: [subscriptionIdentifier(sub)])
    }

    // MARK: - Expected expense

    private func expectedIdentifier(_ exp: ExpectedExpense) -> String {
        "expected-\(exp.id.uuidString)"
    }

    func scheduleNotification(for expected: ExpectedExpense) async {
        let id = expectedIdentifier(expected)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard expected.notificationsEnabled, !expected.isPaid else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let leadSeconds = TimeInterval(max(0, expected.notificationLeadDays) * 86_400)
        let fireDate = expected.dueDate.addingTimeInterval(-leadSeconds)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming expense"
        let leadText = expected.notificationLeadDays == 0
            ? "today"
            : "in \(expected.notificationLeadDays) day\(expected.notificationLeadDays == 1 ? "" : "s")"
        content.body = "\(expected.name) is due \(leadText)."
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do { try await center.add(request) } catch {
            print("NotificationService: failed to schedule expected expense notification: \(error)")
        }
    }

    func cancelNotification(for expected: ExpectedExpense) {
        center.removePendingNotificationRequests(withIdentifiers: [expectedIdentifier(expected)])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Budget warnings

    /// Schedule a one-shot budget warning notification ~1 second in the future
    /// (so iOS displays the banner reliably, even when the app is foregrounded
    /// thanks to the foreground delegate).
    func scheduleBudgetWarning(
        categoryName: String,
        percent: Int,
        isOver: Bool
    ) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = isOver ? "Budget exceeded" : "Budget alert"
        content.body = isOver
            ? "\(categoryName) is over your monthly budget."
            : "\(categoryName) is at \(percent)% of your monthly budget."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "budget-\(categoryName)-\(isOver ? "over" : "80")-\(UUID().uuidString.prefix(8))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do { try await center.add(request) } catch {
            print("NotificationService: failed to schedule budget warning: \(error)")
        }
    }
}

// MARK: - Foreground display delegate

/// Concrete delegate that tells iOS to show notification banners even while the
/// app is in the foreground. Used by ExpenseTrackerApp at launch.
@MainActor
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
