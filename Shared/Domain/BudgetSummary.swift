import Foundation
import SpendCore

/// Everything the Today screen and widget show, computed from a snapshot.
struct BudgetSummary {
    var breakdown: BudgetBreakdown?
    var runOut: RunOutResult
    var model: ForecastModel
    var periodStart: Date?
    var spentSincePeriodStart: Money

    static func compute(_ s: LedgerSnapshot, now: Date = .now) -> BudgetSummary {
        let topUps = s.topUpDates
        let model = Forecaster.fit(transactions: s.transactions, tags: s.tags + eventTags(s), topUps: topUps, today: now)
        let periodStart = topUps.filter { $0 <= now }.max()
        let spent = s.transactions
            .filter { $0.date >= (periodStart ?? .distantPast) && $0.date <= now }
            .map(\.spending).sum()

        guard let checkpoint = s.checkpoint else {
            return BudgetSummary(breakdown: nil, runOut: .noData, model: model, periodStart: periodStart, spentSincePeriodStart: spent)
        }
        let input = BudgetInput(checkpoint: checkpoint, transactions: s.transactions, ious: s.ious,
                                fixedCosts: s.fixedCosts, events: s.events, now: now, nextTopUp: AppSettings.nextTopUp)
        let b = SafeToSpendEngine.compute(input)
        let runOut = RunOutProjector.project(available: b.available, spentToday: b.spentToday, model: model, today: now,
                                             nextTopUp: b.topUpStale ? nil : b.effectiveTopUp, tagsByDay: s.tagsByDay)
        return BudgetSummary(breakdown: b, runOut: runOut, model: model, periodStart: periodStart, spentSincePeriodStart: spent)
    }

    private static func eventTags(_ s: LedgerSnapshot) -> [DayTag] {
        s.events.compactMap { e in e.tag.map { DayTag(day: e.date, tag: $0) } }
    }

    var runOutText: String {
        switch runOut {
        case .noData: "Log a few days to see your run-out date"
        case .lasts:
            if let b = breakdown, !b.topUpStale {
                "Lasts until top-up on \(b.effectiveTopUp.formatted(.dateTime.day().month()))"
            } else {
                "Lasts the next 4 months at this pace"
            }
        case .runsOut(let date):
            IST.isSameDay(date, .now) ? "You're out of safe money today" : "At this pace you run out on \(date.formatted(.dateTime.day().month()))"
        }
    }

    var isRunningOut: Bool {
        if case .runsOut = runOut { true } else { false }
    }
}
