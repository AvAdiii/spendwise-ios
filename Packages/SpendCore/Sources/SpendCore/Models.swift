import Foundation

public enum TxKind: String, Codable, Sendable, CaseIterable {
    case spend, friendPaid, income, settleOut, settleIn, transfer
}

public enum TxSource: String, Codable, Sendable {
    case upi, cash, atm, none
}

/// A ledger entry as SpendCore sees it. The app persists these via SwiftData.
public struct TransactionRecord: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var date: Date
    public var amount: Money
    public var kind: TxKind
    public var source: TxSource
    public var category: String?
    public var payee: String?
    public var ref: String?
    /// Portion that counts as the user's own spending (spend / friendPaid only).
    public var myShare: Money
    public var friendID: UUID?
    public var needsReview: Bool
    public var note: String?

    public init(id: UUID = UUID(), date: Date, amount: Money, kind: TxKind, source: TxSource,
                category: String? = nil, payee: String? = nil, ref: String? = nil,
                myShare: Money? = nil, friendID: UUID? = nil, needsReview: Bool = false, note: String? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.kind = kind
        self.source = source
        self.category = category
        self.payee = payee
        self.ref = ref
        self.myShare = myShare ?? ((kind == .spend || kind == .friendPaid) ? amount : .zero)
        self.friendID = friendID
        self.needsReview = needsReview
        self.note = note
    }

    /// Effect on the tracked bank account.
    public var bankDelta: Money {
        switch kind {
        case .spend: source == .cash ? .zero : -amount
        case .friendPaid: .zero
        case .income, .settleIn: amount
        case .settleOut: source == .cash ? .zero : -amount
        case .transfer: -amount
        }
    }

    /// Effect on the cash wallet.
    public var cashDelta: Money {
        switch kind {
        case .spend, .settleOut: source == .cash ? -amount : .zero
        case .transfer: source == .atm ? amount : .zero
        default: .zero
        }
    }

    /// Amount that counts as the user's spending.
    public var spending: Money {
        (kind == .spend || kind == .friendPaid) ? myShare : .zero
    }
}

public struct Friend: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var aliases: [String]
    public var vpa: String?

    public init(id: UUID = UUID(), name: String, aliases: [String] = [], vpa: String? = nil) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.vpa = vpa
    }
}

public enum IOUDirection: String, Codable, Sendable {
    /// User owes the friend (payable).
    case iOwe
    /// Friend owes the user (receivable).
    case theyOwe
}

public struct IOU: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var friendID: UUID
    public var direction: IOUDirection
    public var amount: Money
    public var settled: Money
    public var createdAt: Date
    public var note: String?

    public init(id: UUID = UUID(), friendID: UUID, direction: IOUDirection, amount: Money,
                settled: Money = .zero, createdAt: Date, note: String? = nil) {
        self.id = id
        self.friendID = friendID
        self.direction = direction
        self.amount = amount
        self.settled = settled
        self.createdAt = createdAt
        self.note = note
    }

    public var outstanding: Money { (amount - settled).clamped(min: .zero) }
    public var isOpen: Bool { outstanding.isPositive }
}

public enum FixedCostSchedule: Hashable, Codable, Sendable {
    case once(Date)
    /// Day of month 1…31; clamps to the month's last day.
    case monthly(day: Int)
}

public struct FixedCost: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var amount: Money
    public var schedule: FixedCostSchedule
    /// Lowercased substring of the SMS payee that marks this cost as paid.
    public var payeeKeyword: String?
    /// Occurrences on or before this date are already paid.
    public var paidThrough: Date?

    public init(id: UUID = UUID(), name: String, amount: Money, schedule: FixedCostSchedule,
                payeeKeyword: String? = nil, paidThrough: Date? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.schedule = schedule
        self.payeeKeyword = payeeKeyword
        self.paidThrough = paidThrough
    }

    /// Due dates (start of day) in [from, to).
    public func occurrences(from: Date, to: Date) -> [Date] {
        let start = IST.startOfDay(from), end = IST.startOfDay(to)
        guard start < end else { return [] }
        let cal = IST.calendar
        var result: [Date] = []
        switch schedule {
        case .once(let d):
            let day = IST.startOfDay(d)
            if day >= start && day < end { result.append(day) }
        case .monthly(let dom):
            var comps = cal.dateComponents([.year, .month], from: start)
            for _ in 0..<24 {
                guard let monthStart = cal.date(from: comps),
                      let range = cal.range(of: .day, in: .month, for: monthStart) else { break }
                comps.day = min(dom, range.count)
                if let due = cal.date(from: comps) {
                    if due >= end { break }
                    if due >= start { result.append(due) }
                }
                comps.day = nil
                comps.month = (comps.month ?? 1) + 1
            }
        }
        if let paid = paidThrough.map(IST.startOfDay) {
            result.removeAll { $0 <= paid }
        }
        return result
    }
}

public struct PlannedEvent: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var date: Date
    public var estimate: Money
    public var tag: String?

    public init(id: UUID = UUID(), name: String, date: Date, estimate: Money, tag: String? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.estimate = estimate
        self.tag = tag
    }
}

/// User-confirmed balances at a moment in time; anchors the computed balance.
public struct BalanceCheckpoint: Hashable, Codable, Sendable {
    public var date: Date
    public var bank: Money
    public var cash: Money

    public init(date: Date, bank: Money, cash: Money) {
        self.date = date
        self.bank = bank
        self.cash = cash
    }
}

public struct DayTag: Hashable, Codable, Sendable {
    public var day: Date
    public var tag: String

    public init(day: Date, tag: String) {
        self.day = IST.startOfDay(day)
        self.tag = tag.lowercased()
    }
}
