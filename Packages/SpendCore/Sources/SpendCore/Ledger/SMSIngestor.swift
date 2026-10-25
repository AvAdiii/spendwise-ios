import Foundation

public struct IngestContext: Sendable {
    public var friends: [Friend]
    public var ious: [IOU]
    public var knownRefs: Set<String>
    public var categorizer: RulesCategorizer
    public var fixedCosts: [FixedCost]
    /// Credits at or above this with no friend match are treated as top-ups.
    public var topUpThreshold: Money

    public init(friends: [Friend], ious: [IOU], knownRefs: Set<String>, categorizer: RulesCategorizer,
                fixedCosts: [FixedCost], topUpThreshold: Money = Money(rupees: 1000)) {
        self.friends = friends
        self.ious = ious
        self.knownRefs = knownRefs
        self.categorizer = categorizer
        self.fixedCosts = fixedCosts
        self.topUpThreshold = topUpThreshold
    }
}

public enum IngestSuggestion: Hashable, Sendable {
    case pickCategory
    case confirmSettlement(friendID: UUID, outstanding: Money)
    case askTopUpDate
}

public struct IngestResult: Hashable, Sendable {
    public var transaction: TransactionRecord
    /// Additional records, e.g. the income part of an over-payment.
    public var extra: [TransactionRecord]
    public var settlements: [IOUSettlement]
    public var fixedCostPaid: (id: UUID, dueDate: Date)?
    public var suggestion: IngestSuggestion?

    public static func == (l: IngestResult, r: IngestResult) -> Bool {
        l.transaction == r.transaction && l.extra == r.extra && l.settlements == r.settlements
            && l.fixedCostPaid?.id == r.fixedCostPaid?.id && l.suggestion == r.suggestion
    }

    public func hash(into h: inout Hasher) { h.combine(transaction) }
}

/// Turns a parsed bank SMS into ledger changes. Pure: the caller persists the result.
public enum SMSIngestor {
    /// Returns nil when the SMS reference was already recorded.
    public static func ingest(_ sms: ParsedSMS, context: IngestContext) -> IngestResult? {
        if let ref = sms.ref, context.knownRefs.contains(ref) { return nil }

        if sms.kind == .atm {
            let tx = TransactionRecord(date: sms.date, amount: sms.amount, kind: .transfer, source: .atm,
                                       category: nil, payee: "ATM withdrawal", ref: sms.ref)
            return IngestResult(transaction: tx, extra: [], settlements: [], fixedCostPaid: nil, suggestion: nil)
        }

        let friend = context.friends.first { $0.matches(payee: sms.payee) }
        switch sms.direction {
        case .debit: return debit(sms, friend: friend, context: context)
        case .credit: return credit(sms, friend: friend, context: context)
        }
    }

    private static func debit(_ sms: ParsedSMS, friend: Friend?, context: IngestContext) -> IngestResult {
        if let friend {
            let owed = Ledger.balances(context.ious)[friend.id]?.payable ?? .zero
            if owed.isPositive {
                if abs(owed.paise - sms.amount.paise) <= 100 {
                    let plan = Ledger.settlementPlan(amount: owed, friendID: friend.id, direction: .iOwe, ious: context.ious)
                    let tx = TransactionRecord(date: sms.date, amount: sms.amount, kind: .settleOut, source: .upi,
                                               payee: sms.payee, ref: sms.ref, friendID: friend.id)
                    return IngestResult(transaction: tx, extra: [], settlements: plan.applied, fixedCostPaid: nil, suggestion: nil)
                }
                let tx = TransactionRecord(date: sms.date, amount: sms.amount, kind: .spend, source: .upi,
                                           category: context.categorizer.categorize(payee: sms.payee),
                                           payee: sms.payee, ref: sms.ref, friendID: friend.id, needsReview: true)
                return IngestResult(transaction: tx, extra: [], settlements: [], fixedCostPaid: nil,
                                    suggestion: .confirmSettlement(friendID: friend.id, outstanding: owed))
            }
        }

        let fixed = matchFixedCost(sms, costs: context.fixedCosts)
        let category = context.categorizer.categorize(payee: sms.payee) ?? (fixed != nil ? "Bills & Recharge" : nil)
        let tx = TransactionRecord(date: sms.date, amount: sms.amount, kind: .spend, source: .upi,
                                   category: category, payee: sms.payee, ref: sms.ref, friendID: friend?.id)
        return IngestResult(transaction: tx, extra: [], settlements: [], fixedCostPaid: fixed,
                            suggestion: category == nil ? .pickCategory : nil)
    }

    private static func credit(_ sms: ParsedSMS, friend: Friend?, context: IngestContext) -> IngestResult {
        if let friend {
            let plan = Ledger.settlementPlan(amount: sms.amount, friendID: friend.id, direction: .theyOwe, ious: context.ious)
            let applied = plan.applied.map(\.amount).sum()
            if applied.isPositive {
                let tx = TransactionRecord(date: sms.date, amount: applied, kind: .settleIn, source: .upi,
                                           payee: sms.payee, ref: sms.ref, friendID: friend.id)
                var extra: [TransactionRecord] = []
                if plan.excess.isPositive {
                    extra.append(TransactionRecord(date: sms.date, amount: plan.excess, kind: .income, source: .upi,
                                                   payee: sms.payee, ref: sms.ref.map { "\($0)-excess" }, friendID: friend.id))
                }
                return IngestResult(transaction: tx, extra: extra, settlements: plan.applied, fixedCostPaid: nil, suggestion: nil)
            }
        }
        let tx = TransactionRecord(date: sms.date, amount: sms.amount, kind: .income, source: .upi,
                                   payee: sms.payee, ref: sms.ref, friendID: friend?.id)
        let topUp = friend == nil && sms.amount >= context.topUpThreshold
        return IngestResult(transaction: tx, extra: [], settlements: [], fixedCostPaid: nil,
                            suggestion: topUp ? .askTopUpDate : nil)
    }

    /// First unpaid occurrence within ±7 days whose keyword is in the payee and amount is within 10%.
    private static func matchFixedCost(_ sms: ParsedSMS, costs: [FixedCost]) -> (id: UUID, dueDate: Date)? {
        guard let payee = sms.payee.map(RulesCategorizer.normalize) else { return nil }
        for cost in costs {
            guard let k = cost.payeeKeyword.map(RulesCategorizer.normalize), !k.isEmpty, payee.contains(k) else { continue }
            let tolerance = max(cost.amount.paise / 10, 100)
            guard abs(cost.amount.paise - sms.amount.paise) <= tolerance else { continue }
            let window = cost.occurrences(from: IST.addDays(-7, to: sms.date), to: IST.addDays(8, to: sms.date))
            if let due = window.first { return (cost.id, due) }
        }
        return nil
    }
}
