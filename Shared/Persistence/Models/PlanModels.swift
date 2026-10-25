import Foundation
import SpendCore
import SwiftData

@Model
final class FixedCostModel {
    var id: UUID = UUID()
    var name: String = ""
    var amountPaise: Int = 0
    /// Set for one-off costs.
    var onceDate: Date?
    /// Set for monthly costs (1…31).
    var monthlyDay: Int?
    var payeeKeyword: String?
    var paidThrough: Date?

    init(name: String, amount: Money, onceDate: Date? = nil, monthlyDay: Int? = nil, payeeKeyword: String? = nil) {
        self.name = name
        amountPaise = amount.paise
        self.onceDate = onceDate
        self.monthlyDay = monthlyDay
        self.payeeKeyword = payeeKeyword
    }

    var fixedCost: FixedCost {
        let schedule: FixedCostSchedule = if let monthlyDay { .monthly(day: monthlyDay) } else { .once(onceDate ?? .now) }
        return FixedCost(id: id, name: name, amount: Money(paise: amountPaise), schedule: schedule,
                         payeeKeyword: payeeKeyword, paidThrough: paidThrough)
    }
}

@Model
final class EventModel {
    var id: UUID = UUID()
    var name: String = ""
    var date: Date = Date.now
    var estimatePaise: Int = 0
    var tag: String?

    init(name: String, date: Date, estimate: Money, tag: String? = nil) {
        self.name = name
        self.date = date
        estimatePaise = estimate.paise
        self.tag = tag
    }

    var event: PlannedEvent {
        PlannedEvent(id: id, name: name, date: date, estimate: Money(paise: estimatePaise), tag: tag)
    }
}

@Model
final class TagModel {
    enum Source: String { case manual, calendar, anomaly }

    var id: UUID = UUID()
    var day: Date = Date.now
    var tag: String = ""
    var sourceRaw: String = Source.manual.rawValue

    init(day: Date, tag: String, source: Source) {
        self.day = IST.startOfDay(day)
        self.tag = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        sourceRaw = source.rawValue
    }

    var dayTag: DayTag { DayTag(day: day, tag: tag) }
}

@Model
final class RuleModel {
    var keyword: String = ""
    var category: String = ""
    var exact: Bool = true

    init(keyword: String, category: String, exact: Bool) {
        self.keyword = RulesCategorizer.normalize(keyword)
        self.category = category
        self.exact = exact
    }

    var rule: CategoryRule { CategoryRule(keyword: keyword, category: category, exact: exact) }
}

@Model
final class CheckpointModel {
    var date: Date = Date.now
    var bankPaise: Int = 0
    var cashPaise: Int = 0

    init(date: Date, bank: Money, cash: Money) {
        self.date = date
        bankPaise = bank.paise
        cashPaise = cash.paise
    }

    var checkpoint: BalanceCheckpoint {
        BalanceCheckpoint(date: date, bank: Money(paise: bankPaise), cash: Money(paise: cashPaise))
    }
}

@Model
final class UnparsedSMSModel {
    var id: UUID = UUID()
    var text: String = ""
    var receivedAt: Date = Date.now

    init(text: String, receivedAt: Date) {
        self.text = text
        self.receivedAt = receivedAt
    }
}
