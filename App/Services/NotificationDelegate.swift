import Foundation
import SwiftData
import UIKit
import UserNotifications

/// Handles the anomaly reply ("party") by tagging that day.
final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in AlertScheduler.shared.registerCategories() }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let reply = response as? UNTextInputNotificationResponse,
              let seconds = response.notification.request.content.userInfo["day"] as? Double else { return }
        let text = reply.userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        await MainActor.run {
            let context = SharedStore.container.mainContext
            context.insert(TagModel(day: Date(timeIntervalSince1970: seconds), tag: text, source: .anomaly))
            try? context.save()
        }
    }
}
