import Foundation
import SpendCore
import SwiftData
import WidgetKit

struct SpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
        completion(context.isPreview ? .sample : load())
    }

    /// The app reloads timelines after every write; the midnight entry rolls the daily allowance over.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
        let now = Date.now
        let midnight = IST.addDays(1, to: IST.startOfDay(now))
        let entries = [load(now: now), load(now: midnight.addingTimeInterval(60))]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(3_600))))
    }

    private func load(now: Date = .now) -> SpendEntry {
        let context = ModelContext(SharedStore.container)
        let summary = BudgetSummary.compute(LedgerSnapshot.load(from: context), now: now)
        guard let b = summary.breakdown else { return .empty }
        return SpendEntry(date: now, leftToday: b.leftToday, allowance: b.dailyAllowance, daysLeft: b.daysLeft,
                          runOutText: summary.runOutText, isRunningOut: summary.isRunningOut,
                          payable: b.payables, receivable: b.receivables)
    }
}
