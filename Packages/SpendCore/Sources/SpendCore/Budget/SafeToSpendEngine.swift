import Foundation

public struct BudgetInput: Sendable {
    public var checkpoint: BalanceCheckpoint
    public var transactions: [TransactionRecord]
    public var ious: [IOU]
    public var fixedCosts: [FixedCost]
    public var events: [PlannedEvent]
    public var now: Date
    public var nextTopUp: Date?

    public init(checkpoint: BalanceCheckpoint, transactions: [TransactionRecord], ious: [IOU],
                fixedCosts: [FixedCost], events: [PlannedEvent], now: Date, nextTopUp: Date?) {
        self.checkpoint = checkpoint
        self.transactions = transactions
        self.ious = ious
        self.fixedCosts = fixedCosts
        self.events = events
        self.now = now
        self.nextTopUp = nextTopUp
    }
}

public struct BudgetBreakdown: Hashable, Sendable {
    public var bank: Money
    public var cash: Money
    public var liquid: Money { bank + cash }
    public var payables: Money
    public var receivables: Money
    public var fixedDue: Money
    public var eventsDue: Money
    public var committed: Money { payables + fixedDue + eventsDue }
    public var available: Money { liquid - committed }
    public var daysLeft: Int
    public var spentToday: Money
    /// Today's even share of what was available at the start of the day.
    public var dailyAllowance: Money
    public var leftToday: Money { dailyAllowance - spentToday }
    /// True when no future top-up date is set; daysLeft then falls back to 30.
    public var topUpStale: Bool
    public var effectiveTopUp: Date
}

public enum SafeToSpendEngine {
    public static let fallbackDays = 30

    public static func compute(_ input: BudgetInput) -> BudgetBreakdown {
        let after = input.transactions.filter { $0.date > input.checkpoint.date && $0.date <= input.now }
        let bank = input.checkpoint.bank + after.map(\.bankDelta).sum()
        let cash = input.checkpoint.cash + after.map(\.cashDelta).sum()

        let today = IST.startOfDay(input.now)
        let stale = input.nextTopUp.map { IST.startOfDay($0) <= today } ?? true
        let topUp = stale ? IST.addDays(fallbackDays, to: today) : IST.startOfDay(input.nextTopUp!)
        let daysLeft = max(1, IST.days(from: today, to: topUp))

        let spentToday = input.transactions
            .filter { IST.isSameDay($0.date, input.now) && $0.date <= input.now }
            .map(\.spending).sum()

        let fixedDue = input.fixedCosts
            .map { cost in cost.amount * Double(cost.occurrences(from: today, to: topUp).count) }
            .sum()

        // An event happening today is assumed to be partly paid for by today's spending.
        let todayEvents = input.events.filter { IST.isSameDay($0.date, today) }.map(\.estimate).sum()
        let futureEvents = input.events
            .filter { IST.startOfDay($0.date) > today && IST.startOfDay($0.date) < topUp }
            .map(\.estimate).sum()
        let eventsDue = futureEvents + (todayEvents - spentToday).clamped(min: .zero)

        var b = BudgetBreakdown(bank: bank, cash: cash,
                                payables: Ledger.totalPayable(input.ious),
                                receivables: Ledger.totalReceivable(input.ious),
                                fixedDue: fixedDue, eventsDue: eventsDue, daysLeft: daysLeft,
                                spentToday: spentToday, dailyAllowance: .zero,
                                topUpStale: stale, effectiveTopUp: topUp)
        b.dailyAllowance = (b.available + spentToday) / daysLeft
        return b
    }
}
