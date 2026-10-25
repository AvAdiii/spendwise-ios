import Foundation
import SpendCore
import SwiftData
import WidgetKit

enum SMSIngestOutcome: Equatable {
    case recorded(UUID, IngestSuggestion?)
    case duplicate
    case unparsed
}

/// Every write to the ledger goes through here so widgets and alerts stay in sync.
@MainActor
struct SpendService {
    let context: ModelContext
    var parser: any BankSMSParser = SBISMSParser()
    /// Tests turn this off; it reloads widgets and re-evaluates alerts.
    var sideEffects = true

    // MARK: SMS capture

    func ingestSMS(_ text: String, receivedAt: Date = .now) -> SMSIngestOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = parser.parse(trimmed, receivedAt: receivedAt) else {
            context.insert(UnparsedSMSModel(text: trimmed, receivedAt: receivedAt))
            commit()
            return .unparsed
        }
        let snapshot = LedgerSnapshot.load(from: context)
        let refs = Set(snapshot.transactions.compactMap(\.ref))
        let ctx = IngestContext(friends: snapshot.friends, ious: snapshot.ious, knownRefs: refs,
                                categorizer: snapshot.categorizer, fixedCosts: snapshot.fixedCosts)
        guard let result = SMSIngestor.ingest(parsed, context: ctx) else { return .duplicate }

        context.insert(TxModel(record: result.transaction, rawSMS: trimmed))
        for extra in result.extra { context.insert(TxModel(record: extra)) }
        applySettlements(result.settlements)
        if let paid = result.fixedCostPaid, let cost = fixedCost(paid.id) {
            cost.paidThrough = max(cost.paidThrough ?? .distantPast, paid.dueDate)
        }
        commit()
        return .recorded(result.transaction.id, result.suggestion)
    }

    // MARK: Manual logs

    @discardableResult
    func logCash(amount: Money, category: String?, note: String? = nil, date: Date = .now) -> UUID {
        let r = TransactionRecord(date: date, amount: amount, kind: .spend, source: .cash, category: category, note: note)
        context.insert(TxModel(record: r))
        commit()
        return r.id
    }

    /// A friend paid; the user's share is spending now and a payable until settled.
    @discardableResult
    func logFriendPaid(friendID: UUID, total: Money, people: Int?, myShare: Money?, category: String?,
                       note: String? = nil, date: Date = .now) -> UUID {
        let share = SplitCalculator.friendPaid(total: total, people: people ?? 1, myShare: myShare)
        let r = TransactionRecord(date: date, amount: share, kind: .friendPaid, source: .none, category: category,
                                  payee: friend(friendID)?.name, friendID: friendID, note: note)
        context.insert(TxModel(record: r))
        context.insert(IOUModel(friendID: friendID, direction: .iOwe, amount: share, createdAt: date, note: note ?? category,
                                sourceTxID: r.id))
        commit()
        return r.id
    }

    /// The user paid for a group. Attaches to a matching UPI debit from the last 20 minutes if one exists,
    /// otherwise records a cash spend.
    @discardableResult
    func logPaidForGroup(total: Money, friendIDs: [UUID], people: Int?, myShare: Money?, category: String?,
                         note: String? = nil, date: Date = .now) -> UUID {
        let since = date.addingTimeInterval(-20 * 60)
        let recent = (try? context.fetch(FetchDescriptor<TxModel>(predicate: #Predicate { $0.date >= since })))?
            .first { $0.kind == .spend && $0.source == .upi && $0.amountPaise == total.paise && $0.mySharePaise == $0.amountPaise }
        let tx: TxModel
        if let recent {
            tx = recent
            if let category { tx.category = category }
        } else {
            tx = TxModel(record: TransactionRecord(date: date, amount: total, kind: .spend, source: .cash,
                                                   category: category, note: note))
            context.insert(tx)
        }
        split(tx, friendIDs: friendIDs, people: people, myShare: myShare)
        commit()
        return tx.id
    }

    // MARK: Editing

    func split(transactionID: UUID, friendIDs: [UUID], people: Int?, myShare: Money?) {
        guard let tx = transaction(transactionID) else { return }
        split(tx, friendIDs: friendIDs, people: people, myShare: myShare)
        commit()
    }

    private func split(_ tx: TxModel, friendIDs: [UUID], people: Int?, myShare: Money?) {
        removeIOUs(createdBy: tx.id)
        let result = SplitCalculator.paidForGroup(total: tx.amount, people: people, myShare: myShare, friends: friendIDs)
        tx.mySharePaise = result.myShare.paise
        tx.needsReview = false
        for (friendID, share) in result.friendShares where share.isPositive {
            context.insert(IOUModel(friendID: friendID, direction: .theyOwe, amount: share, createdAt: tx.date,
                                    note: tx.payee ?? tx.category, sourceTxID: tx.id))
        }
    }

    func setCategory(transactionID: UUID, category: String, learn: Bool = true) {
        guard let tx = transaction(transactionID) else { return }
        tx.category = category
        if learn, let payee = tx.payee, tx.friendID == nil {
            let key = RulesCategorizer.normalize(payee)
            for old in (try? context.fetch(FetchDescriptor<RuleModel>(predicate: #Predicate { $0.keyword == key && $0.exact == true }))) ?? [] {
                context.delete(old)
            }
            context.insert(RuleModel(keyword: key, category: category, exact: true))
            // Apply to other uncategorised transactions from the same payee.
            for other in (try? context.fetch(FetchDescriptor<TxModel>(predicate: #Predicate { $0.category == nil }))) ?? []
            where other.payee.map(RulesCategorizer.normalize) == key {
                other.category = category
            }
        }
        commit()
    }

    func markTransfer(transactionID: UUID) {
        guard let tx = transaction(transactionID) else { return }
        removeIOUs(createdBy: tx.id)
        tx.kindRaw = TxKind.transfer.rawValue
        tx.mySharePaise = 0
        tx.needsReview = false
        commit()
    }

    func markSpend(transactionID: UUID) {
        guard let tx = transaction(transactionID) else { return }
        tx.kindRaw = TxKind.spend.rawValue
        tx.mySharePaise = tx.amountPaise
        tx.needsReview = false
        commit()
    }

    /// Turns a flagged debit to a friend into a settlement. Any overpayment becomes a receivable.
    func confirmSettlement(transactionID: UUID) {
        guard let tx = transaction(transactionID), let friendID = tx.friendID else { return }
        let ious = LedgerSnapshot.load(from: context).ious
        let plan = Ledger.settlementPlan(amount: tx.amount, friendID: friendID, direction: .iOwe, ious: ious)
        applySettlements(plan.applied)
        if plan.excess.isPositive {
            context.insert(IOUModel(friendID: friendID, direction: .theyOwe, amount: plan.excess, createdAt: tx.date,
                                    note: "Overpaid", sourceTxID: tx.id))
        }
        tx.kindRaw = TxKind.settleOut.rawValue
        tx.mySharePaise = 0
        tx.needsReview = false
        commit()
    }

    func dismissReview(transactionID: UUID) {
        transaction(transactionID)?.needsReview = false
        commit()
    }

    func updateNote(transactionID: UUID, note: String) {
        transaction(transactionID)?.note = note.isEmpty ? nil : note
        commit()
    }

    func delete(transactionID: UUID) {
        guard let tx = transaction(transactionID) else { return }
        removeIOUs(createdBy: tx.id)
        context.delete(tx)
        commit()
    }

    // MARK: Friends

    enum SettleMethod: String, CaseIterable, Identifiable {
        case cash, upiMissed, forgive
        var id: String { rawValue }
        var title: String {
            switch self {
            case .cash: "Paid in cash"
            case .upiMissed: "Paid by UPI (SMS missed)"
            case .forgive: "Just close it"
            }
        }
    }

    /// Settles a friend's balance outside SMS capture.
    func settle(friendID: UUID, amount: Money, direction: IOUDirection, method: SettleMethod) {
        let ious = LedgerSnapshot.load(from: context).ious
        let plan = Ledger.settlementPlan(amount: amount, friendID: friendID, direction: direction, ious: ious)
        applySettlements(plan.applied)
        let settled = amount - plan.excess
        if method != .forgive, settled.isPositive {
            let kind: TxKind = direction == .iOwe ? .settleOut : .settleIn
            let r = TransactionRecord(date: .now, amount: settled, kind: kind, source: method == .cash ? .cash : .upi,
                                      payee: friend(friendID)?.name, friendID: friendID)
            context.insert(TxModel(record: r))
        }
        commit()
    }

    func deleteFriend(_ friendID: UUID) {
        for iou in (try? context.fetch(FetchDescriptor<IOUModel>(predicate: #Predicate { $0.friendID == friendID }))) ?? [] {
            context.delete(iou)
        }
        if let f = friend(friendID) { context.delete(f) }
        commit()
    }

    // MARK: Balance

    func recordCheckpoint(bank: Money, cash: Money, date: Date = .now) {
        context.insert(CheckpointModel(date: date, bank: bank, cash: cash))
        commit()
    }

    func recordTopUp(next: Date?) {
        AppSettings.lastTopUp = .now
        AppSettings.nextTopUp = next
        commit()
    }

    // MARK: Helpers

    func commit() {
        do {
            try context.save()
        } catch {
            assertionFailure("Save failed: \(error)")
        }
        guard sideEffects else { return }
        WidgetCenter.shared.reloadAllTimelines()
        let ctx = context
        Task { await AlertScheduler.shared.evaluate(context: ctx) }
    }

    private func applySettlements(_ settlements: [IOUSettlement]) {
        for s in settlements {
            let id = s.iouID
            if let iou = (try? context.fetch(FetchDescriptor<IOUModel>(predicate: #Predicate { $0.id == id })))?.first {
                iou.settledPaise += s.amount.paise
            }
        }
    }

    private func removeIOUs(createdBy txID: UUID) {
        let id: UUID? = txID
        for iou in (try? context.fetch(FetchDescriptor<IOUModel>(predicate: #Predicate { $0.sourceTxID == id }))) ?? [] {
            context.delete(iou)
        }
    }

    func transaction(_ id: UUID) -> TxModel? {
        (try? context.fetch(FetchDescriptor<TxModel>(predicate: #Predicate { $0.id == id })))?.first
    }

    func friend(_ id: UUID) -> FriendModel? {
        (try? context.fetch(FetchDescriptor<FriendModel>(predicate: #Predicate { $0.id == id })))?.first
    }

    private func fixedCost(_ id: UUID) -> FixedCostModel? {
        (try? context.fetch(FetchDescriptor<FixedCostModel>(predicate: #Predicate { $0.id == id })))?.first
    }
}
