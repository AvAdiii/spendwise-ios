import Foundation
import Testing
@testable import SpendCore

@Suite struct RulesCategorizerTests {
    @Test func defaultKeywordsMatch() {
        let c = RulesCategorizer.withDefaults()
        #expect(c.categorize(payee: "SWIGGY") == "Food")
        #expect(c.categorize(payee: "MADRUS KITCHEN") == "Food")
        #expect(c.categorize(payee: "Zepto Marketplace") == "Groceries")
        #expect(c.categorize(payee: "IRCTC UTS") == "Travel")
        #expect(c.categorize(payee: "PRIYA SHARMA") == nil)
    }

    @Test func shortKeywordsNeedWholeWord() {
        let c = RulesCategorizer.withDefaults()
        // "vi" must not match inside "VIKRAM".
        #expect(c.categorize(payee: "VIKRAM SINGH") == nil)
        #expect(c.categorize(payee: "VI RECHARGE") == "Bills & Recharge")
    }

    @Test func learnedExactRuleBeatsKeyword() {
        var c = RulesCategorizer.withDefaults()
        c.learn(payee: "Madrus  Kitchen", category: "Groceries")
        #expect(c.categorize(payee: "MADRUS KITCHEN") == "Groceries")
        #expect(c.categorize(payee: "OTHER KITCHEN") == "Food")
        c.learn(payee: "MADRUS KITCHEN", category: "Food")
        #expect(c.rules.filter { $0.exact }.count == 1)
    }
}

@Suite struct SplitTests {
    let a = UUID(), b = UUID(), c = UUID()

    @Test func paidForGroupEvenly() {
        let r = SplitCalculator.paidForGroup(total: Money(rupees: 1200), people: 4, friends: [a, b, c])
        #expect(r.myShare == Money(rupees: 300))
        #expect(r.friendShares[a] == Money(rupees: 300))
        #expect(r.friendShares.values.sum() + r.myShare == Money(rupees: 1200))
    }

    @Test func paidForGroupWithExplicitShare() {
        let r = SplitCalculator.paidForGroup(total: Money(rupees: 1000), myShare: Money(rupees: 400), friends: [a, b])
        #expect(r.myShare == Money(rupees: 400))
        #expect(r.friendShares[a] == Money(rupees: 300))
        #expect(r.friendShares[b] == Money(rupees: 300))
    }

    @Test func untrackedPeopleStayOnMyShare() {
        // 5 people, only 2 friends tracked: the 2 untracked shares are not receivables.
        let r = SplitCalculator.paidForGroup(total: Money(rupees: 1000), people: 5, friends: [a, b])
        #expect(r.friendShares[a] == Money(rupees: 200))
        #expect(r.myShare == Money(rupees: 600))
    }

    @Test func friendPaidShare() {
        #expect(SplitCalculator.friendPaid(total: Money(rupees: 900), people: 3) == Money(rupees: 300))
        #expect(SplitCalculator.friendPaid(total: Money(rupees: 900), people: 3, myShare: Money(rupees: 100)) == Money(rupees: 100))
    }
}

@Suite struct LedgerTests {
    let rahul = UUID()

    @Test func balancesNetPerFriend() {
        let ious = [
            IOU(friendID: rahul, direction: .iOwe, amount: Money(rupees: 500), createdAt: IST.date(2026, 10, 1)),
            IOU(friendID: rahul, direction: .theyOwe, amount: Money(rupees: 200), createdAt: IST.date(2026, 10, 2)),
            IOU(friendID: rahul, direction: .iOwe, amount: Money(rupees: 100), settled: Money(rupees: 100), createdAt: IST.date(2026, 10, 3)),
        ]
        let b = Ledger.balances(ious)[rahul]!
        #expect(b.payable == Money(rupees: 500))
        #expect(b.receivable == Money(rupees: 200))
        #expect(b.net == Money(rupees: -300))
    }

    @Test func settlementAppliesOldestFirstAndReturnsExcess() {
        let first = IOU(friendID: rahul, direction: .iOwe, amount: Money(rupees: 300), createdAt: IST.date(2026, 10, 1))
        let second = IOU(friendID: rahul, direction: .iOwe, amount: Money(rupees: 500), createdAt: IST.date(2026, 10, 5))
        let plan = Ledger.settlementPlan(amount: Money(rupees: 1000), friendID: rahul, direction: .iOwe, ious: [second, first])
        #expect(plan.applied == [IOUSettlement(iouID: first.id, amount: Money(rupees: 300)),
                                 IOUSettlement(iouID: second.id, amount: Money(rupees: 500))])
        #expect(plan.excess == Money(rupees: 200))
    }
}

@Suite struct SMSIngestorTests {
    let parser = SBISMSParser()
    let now = IST.date(2026, 10, 25, 21, 0)
    let priya = Friend(name: "Priya", aliases: ["PRIYA SHARMA"])
    let karthik = Friend(name: "Karthik", aliases: ["KARTHIK RAMESHWAR"])

    func debit(_ amount: String, to payee: String, ref: String = "600000000101") -> ParsedSMS {
        parser.parse("Dear UPI user A/C X4321 debited by \(amount) on date 25Oct26 trf to \(payee) Refno \(ref) If not u?", receivedAt: now)!
    }

    func credit(_ amount: String, from payee: String, ref: String = "777700001111") -> ParsedSMS {
        parser.parse("Dear SBI User, your A/c X4321-credited by Rs.\(amount) on 25Oct26 transfer from \(payee) Ref No \(ref) -SBI", receivedAt: now)!
    }

    func ctx(ious: [IOU] = [], refs: Set<String> = [], fixed: [FixedCost] = []) -> IngestContext {
        IngestContext(friends: [priya, karthik], ious: ious, knownRefs: refs,
                      categorizer: .withDefaults(), fixedCosts: fixed)
    }

    @Test func duplicateRefIsIgnored() {
        let out = SMSIngestor.ingest(debit("239.00", to: "SWIGGY"), context: ctx(refs: ["600000000101"]))
        #expect(out == nil)
    }

    @Test func merchantDebitBecomesCategorisedSpend() throws {
        let r = try #require(SMSIngestor.ingest(debit("239.00", to: "SWIGGY"), context: ctx()))
        #expect(r.transaction.kind == .spend)
        #expect(r.transaction.category == "Food")
        #expect(r.transaction.needsReview == false)
        #expect(r.suggestion == nil)
    }

    @Test func unknownPayeeAsksForCategory() throws {
        let r = try #require(SMSIngestor.ingest(debit("50.00", to: "RANDOM SHOP"), context: ctx()))
        #expect(r.transaction.category == nil)
        #expect(r.suggestion == .pickCategory)
    }

    @Test func exactPayableAmountAutoSettles() throws {
        let iou = IOU(friendID: priya.id, direction: .iOwe, amount: Money(rupees: 239), createdAt: IST.date(2026, 10, 20))
        let r = try #require(SMSIngestor.ingest(debit("239.00", to: "PRIYA SHARMA"), context: ctx(ious: [iou])))
        #expect(r.transaction.kind == .settleOut)
        #expect(r.transaction.friendID == priya.id)
        #expect(r.settlements == [IOUSettlement(iouID: iou.id, amount: Money(rupees: 239))])
    }

    @Test func truncatedPayeeMatchesLongerAlias() throws {
        let iou = IOU(friendID: karthik.id, direction: .iOwe, amount: Money(rupees: 20), createdAt: IST.date(2026, 10, 20))
        let r = try #require(SMSIngestor.ingest(debit("20.00", to: "KARTHIK RAMESHWA"), context: ctx(ious: [iou])))
        #expect(r.transaction.kind == .settleOut)
    }

    @Test func mismatchedAmountToCreditorIsFlagged() throws {
        let iou = IOU(friendID: priya.id, direction: .iOwe, amount: Money(rupees: 500), createdAt: IST.date(2026, 10, 20))
        let r = try #require(SMSIngestor.ingest(debit("239.00", to: "PRIYA SHARMA"), context: ctx(ious: [iou])))
        #expect(r.transaction.kind == .spend)
        #expect(r.transaction.needsReview)
        #expect(r.suggestion == .confirmSettlement(friendID: priya.id, outstanding: Money(rupees: 500)))
        #expect(r.settlements.isEmpty)
    }

    @Test func creditFromDebtorSettlesAndExcessIsIncome() throws {
        let iou = IOU(friendID: priya.id, direction: .theyOwe, amount: Money(rupees: 300), createdAt: IST.date(2026, 10, 20))
        let r = try #require(SMSIngestor.ingest(credit("500", from: "PRIYA SHARMA"), context: ctx(ious: [iou])))
        #expect(r.transaction.kind == .settleIn)
        #expect(r.transaction.amount == Money(rupees: 300))
        #expect(r.extra.map(\.kind) == [.income])
        #expect(r.extra.first?.amount == Money(rupees: 200))
        #expect(r.extra.first?.ref == "777700001111-excess")
    }

    @Test func largeUnknownCreditAsksForTopUpDate() throws {
        let r = try #require(SMSIngestor.ingest(credit("5000", from: "PAPA"), context: ctx()))
        #expect(r.transaction.kind == .income)
        #expect(r.suggestion == .askTopUpDate)
        let small = try #require(SMSIngestor.ingest(credit("50", from: "PAPA"), context: ctx()))
        #expect(small.suggestion == nil)
    }

    @Test func atmBecomesCashTransfer() throws {
        let p = parser.parse("Dear Customer, Rs.2,000 withdrawn at SBI ATM S1NW000123 from A/cX4321 on 25Oct26 Transaction Number 4521.", receivedAt: now)!
        let r = try #require(SMSIngestor.ingest(p, context: ctx()))
        #expect(r.transaction.kind == .transfer)
        #expect(r.transaction.source == .atm)
        #expect(r.transaction.cashDelta == Money(rupees: 2000))
        #expect(r.transaction.spending == .zero)
    }

    @Test func fixedCostPayeeMarksPaid() throws {
        let jio = FixedCost(name: "Jio recharge", amount: Money(rupees: 349), schedule: .monthly(day: 28), payeeKeyword: "jio")
        let r = try #require(SMSIngestor.ingest(debit("349.00", to: "JIO PREPAID"), context: ctx(fixed: [jio])))
        #expect(r.fixedCostPaid?.id == jio.id)
        #expect(r.fixedCostPaid?.dueDate == IST.date(2026, 10, 28))
        #expect(r.transaction.category == "Bills & Recharge")
    }
}
