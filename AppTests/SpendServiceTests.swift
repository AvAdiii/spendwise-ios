import Foundation
import SpendCore
import SwiftData
import Testing
@testable import Spendwise

@MainActor
@Suite struct SpendServiceTests {
    let container = SharedStore.makeContainer(inMemory: true)
    var context: ModelContext { container.mainContext }
    var service: SpendService { SpendService(context: context, sideEffects: false) }

    let debit = "Dear UPI user A/C X4321 debited by 239.00 on date 25Oct26 trf to PRIYA SHARMA Refno 600000000101 If not u? call-1800111109 for other services-18001234-SBI"
    let received = IST.date(2026, 10, 25, 21, 0)

    @Test func ingestsAndDeduplicatesSMS() throws {
        let first = service.ingestSMS(debit, receivedAt: received)
        guard case .recorded(let id, .pickCategory) = first else { Issue.record("got \(first)"); return }
        #expect(service.ingestSMS(debit, receivedAt: received) == .duplicate)
        let tx = try #require(service.transaction(id))
        #expect(tx.amount == Money(rupees: 239))
        #expect(tx.rawSMS == debit)
    }

    @Test func unparsedSMSIsKept() throws {
        #expect(service.ingestSMS("Your OTP is 1234", receivedAt: received) == .unparsed)
        #expect(try context.fetchCount(FetchDescriptor<UnparsedSMSModel>()) == 1)
    }

    @Test func friendPaidThenSMSSettlementClosesIOU() throws {
        let priya = FriendModel(name: "Priya", aliases: ["PRIYA SHARMA"])
        context.insert(priya)
        service.logFriendPaid(friendID: priya.id, total: Money(rupees: 717), people: 3, myShare: nil, category: "Food",
                              date: IST.date(2026, 10, 24))
        let before = Ledger.balances(LedgerSnapshot.load(from: context).ious)[priya.id]
        #expect(before?.payable == Money(rupees: 239))

        guard case .recorded(let id, nil) = service.ingestSMS(debit, receivedAt: received) else {
            Issue.record("expected auto-settlement"); return
        }
        #expect(service.transaction(id)?.kind == .settleOut)
        let after = Ledger.balances(LedgerSnapshot.load(from: context).ious)[priya.id]
        #expect(after == nil)
    }

    @Test func splitAndCorrectCategoryLearns() throws {
        let rahul = FriendModel(name: "Rahul")
        context.insert(rahul)
        let sms = "Dear UPI user A/C X4321 debited by 1200.00 on date 25Oct26 trf to SRI SAI STORES Refno 111122223333 If not u?"
        guard case .recorded(let id, _) = service.ingestSMS(sms, receivedAt: received) else { Issue.record("not recorded"); return }

        service.split(transactionID: id, friendIDs: [rahul.id], people: 4, myShare: nil)
        #expect(service.transaction(id)?.myShare == Money(rupees: 900))
        #expect(Ledger.totalReceivable(LedgerSnapshot.load(from: context).ious) == Money(rupees: 300))

        service.setCategory(transactionID: id, category: "Groceries")
        let next = "Dear UPI user A/C X4321 debited by 80.00 on date 25Oct26 trf to SRI SAI STORES Refno 444455556666 If not u?"
        guard case .recorded(let nextID, nil) = service.ingestSMS(next, receivedAt: received) else { Issue.record("no rule"); return }
        #expect(service.transaction(nextID)?.category == "Groceries")
    }

    @Test func deletingSplitTransactionRemovesIOUs() throws {
        let rahul = FriendModel(name: "Rahul")
        context.insert(rahul)
        let id = service.logPaidForGroup(total: Money(rupees: 600), friendIDs: [rahul.id], people: 2, myShare: nil, category: "Food")
        #expect(try context.fetchCount(FetchDescriptor<IOUModel>()) == 1)
        service.delete(transactionID: id)
        #expect(try context.fetchCount(FetchDescriptor<IOUModel>()) == 0)
    }

    @Test func backupRoundTrips() throws {
        DemoData.seed(context)
        let before = LedgerSnapshot.load(from: context)
        let url = try BackupService.export(context: context)
        // Keep the container alive: a ModelContext does not retain it.
        let otherContainer = SharedStore.makeContainer(inMemory: true)
        let other = otherContainer.mainContext
        try BackupService.restore(from: url, context: other)
        let after = LedgerSnapshot.load(from: other)
        #expect(after.transactions.count == before.transactions.count)
        #expect(after.ious.map(\.outstanding).sum() == before.ious.map(\.outstanding).sum())
        #expect(after.checkpoint == before.checkpoint)
    }

    @Test func demoSummaryIsComputable() {
        DemoData.seed(context)
        let summary = BudgetSummary.compute(LedgerSnapshot.load(from: context))
        #expect(summary.breakdown != nil)
        #expect(summary.model.mode == .baseline)
    }
}
