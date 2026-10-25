import Foundation

public struct PaceAlert: Hashable, Sendable {
    public var message: String
    /// 10% band of spent fraction; persisted so each band alerts once per top-up.
    public var band: Int
}

public enum PaceAlertEngine {
    public static let threshold = 0.15

    public static func evaluate(periodStart: Date, nextTopUp: Date, now: Date, spentSinceStart: Money,
                                available: Money, lastBand: Int?) -> PaceAlert? {
        let funds = Double((spentSinceStart + available.clamped(min: .zero)).paise)
        let total = IST.days(from: periodStart, to: nextTopUp)
        guard funds > 0, total > 0 else { return nil }
        let elapsed = min(total, IST.days(from: periodStart, to: now) + 1)
        let spentFraction = Double(spentSinceStart.paise) / funds
        let timeFraction = Double(elapsed) / Double(total)
        guard spentFraction - timeFraction > threshold else { return nil }
        let band = Int(spentFraction * 10)
        if let lastBand, band <= lastBand { return nil }
        let pct = band * 10
        let dayWord = elapsed == 1 ? "day" : "days"
        return PaceAlert(message: "You've spent \(pct)% of this top-up in \(elapsed) \(dayWord).", band: band)
    }
}

public enum AnomalyDetector {
    public static let floor = Money(rupees: 300)

    /// Day came in at more than twice its forecast (and above a floor), with no explanation yet.
    public static func isAnomaly(actual: Money, expected: Money, alreadyTagged: Bool) -> Bool {
        !alreadyTagged && actual >= floor && actual.paise > 2 * expected.paise
    }
}

public enum CollectionNudge {
    /// Days 1–3 of the month, when friends have just been paid.
    public static func message(now: Date, receivable: Money, debtors: Int, payable: Money) -> String? {
        guard IST.dayOfMonth(now) <= 3, receivable.isPositive || payable.isPositive else { return nil }
        var parts: [String] = []
        if receivable.isPositive {
            parts.append("collect \(receivable.formatted()) from \(debtors) friend\(debtors == 1 ? "" : "s")")
        }
        if payable.isPositive { parts.append("clear \(payable.formatted()) you owe") }
        return "Payday week: " + parts.joined(separator: " and ") + "."
    }
}

public enum EventWarning {
    /// Warns about a tag starting within `lookahead` days whose learned extra cost eats into the budget.
    public static func message(upcoming: [Date: Set<String>], model: ForecastModel, available: Money,
                               today: Date, lookahead: Int = 3) -> String? {
        guard model.mode == .baseline else { return nil }
        let start = IST.startOfDay(today)
        let horizon = IST.addDays(lookahead, to: start)
        let soon = upcoming.filter { $0.key > start && $0.key <= horizon }
        for tag in Set(soon.values.flatMap { $0 }).sorted() where model.knownTags.contains(tag) {
            let tagDays = upcoming.filter { $0.value.contains(tag) && $0.key > start }.keys.sorted()
            guard let first = tagDays.first else { continue }
            let extra = model.tagExtraCost(tag, on: tagDays)
            guard extra >= Money(rupees: 200) else { continue }
            let untilThen = (0..<IST.days(from: start, to: first)).map { IST.addDays($0, to: start) }
            let pace = untilThen.map { model.expected(on: $0) }.sum()
            let leftForIt = (available - pace).clamped(min: .zero)
            let weekday = IST.calendar.weekdaySymbols[IST.calendar.component(.weekday, from: first) - 1]
            return "\(tag.capitalized) starts \(weekday). It usually costs you \(extra.formatted()) extra; your pace leaves \(leftForIt.formatted()) for it."
        }
        return nil
    }
}
