import Foundation
import SpendCore
import SwiftData
import UserNotifications

/// Local notifications derived from the forecast. Each alert fires once per state change.
@MainActor
final class AlertScheduler {
    static let shared = AlertScheduler()
    static let anomalyCategory = "ANOMALY"
    static let anomalyReplyAction = "ANOMALY_REPLY"

    private let center = UNUserNotificationCenter.current()

    func registerCategories() {
        let reply = UNTextInputNotificationAction(identifier: Self.anomalyReplyAction, title: "Tag this day",
                                                  options: [], textInputButtonTitle: "Save",
                                                  textInputPlaceholder: "party, trip, exam…")
        let category = UNNotificationCategory(identifier: Self.anomalyCategory, actions: [reply], intentIdentifiers: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func evaluate(context: ModelContext, now: Date = .now) async {
        guard !SharedStore.isDemo else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let snapshot = LedgerSnapshot.load(from: context)
        let summary = BudgetSummary.compute(snapshot, now: now)
        guard let b = summary.breakdown else { return }

        // Pace
        if let start = summary.periodStart, !b.topUpStale {
            let key = "pace-\(Int(start.timeIntervalSince1970))"
            if let alert = PaceAlertEngine.evaluate(periodStart: start, nextTopUp: b.effectiveTopUp, now: now,
                                                    spentSinceStart: summary.spentSincePeriodStart, available: b.available,
                                                    lastBand: AppSettings.alertValue(key)) {
                AppSettings.setAlertValue(alert.band, for: key)
                await post(id: key, title: "Spending pace", body: alert.message)
            }
        }

        // Start-of-month collection nudge, once per day.
        let dayKey = "nudge-\(Int(IST.startOfDay(now).timeIntervalSince1970))"
        let debtors = Ledger.balances(snapshot.ious).values.count { $0.receivable.isPositive }
        if AppSettings.alertValue(dayKey) == nil,
           let msg = CollectionNudge.message(now: now, receivable: b.receivables, debtors: debtors, payable: b.payables) {
            AppSettings.setAlertValue(1, for: dayKey)
            await post(id: dayKey, title: "Settle up", body: msg)
        }

        // Upcoming tagged event.
        if let msg = EventWarning.message(upcoming: snapshot.tagsByDay, model: summary.model, available: b.available, today: now) {
            let key = "event-\(msg.hashValue)"
            if AppSettings.alertValue(key) == nil {
                AppSettings.setAlertValue(1, for: key)
                await post(id: key, title: "Heads up", body: msg)
            }
        }

        await checkAnomalies(snapshot: snapshot, model: summary.model, now: now)
    }

    /// Asks "what was happening?" for unexplained expensive days since the last check.
    private func checkAnomalies(snapshot: LedgerSnapshot, model: ForecastModel, now: Date) async {
        guard model.mode == .baseline else { return }
        let yesterday = IST.addDays(-1, to: IST.startOfDay(now))
        var day = AppSettings.anomalyCheckedThrough.map { IST.addDays(1, to: $0) } ?? yesterday
        let tags = snapshot.tagsByDay
        while day <= yesterday {
            let actual = snapshot.transactions.filter { IST.isSameDay($0.date, day) }.map(\.spending).sum()
            let expected = model.expected(on: day)
            if AnomalyDetector.isAnomaly(actual: actual, expected: expected, alreadyTagged: !(tags[day] ?? []).isEmpty) {
                let label = day.formatted(.dateTime.day().month())
                await post(id: "anomaly-\(Int(day.timeIntervalSince1970))", title: "What was happening on \(label)?",
                           body: "You spent \(actual.formatted()), about \(actual.paise / max(1, expected.paise))× a usual day. Reply with one word to tag it.",
                           category: Self.anomalyCategory, userInfo: ["day": day.timeIntervalSince1970])
            }
            day = IST.addDays(1, to: day)
        }
        AppSettings.anomalyCheckedThrough = yesterday
    }

    private func post(id: String, title: String, body: String, category: String? = nil, userInfo: [String: Any] = [:]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        if let category { content.categoryIdentifier = category }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await center.add(request)
    }
}
