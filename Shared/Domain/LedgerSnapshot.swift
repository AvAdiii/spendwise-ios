import Foundation
import SpendCore
import SwiftData

/// Value-type copy of everything SpendCore needs, loaded from SwiftData in one go.
struct LedgerSnapshot {
    var transactions: [TransactionRecord] = []
    var friends: [Friend] = []
    var ious: [IOU] = []
    var fixedCosts: [FixedCost] = []
    var events: [PlannedEvent] = []
    var tags: [DayTag] = []
    var rules: [CategoryRule] = []
    var checkpoint: BalanceCheckpoint?

    static func load(from context: ModelContext) -> LedgerSnapshot {
        LedgerSnapshot(
            transactions: (try? context.fetch(FetchDescriptor<TxModel>(sortBy: [SortDescriptor(\.date)]))) ?? [],
            friends: (try? context.fetch(FetchDescriptor<FriendModel>())) ?? [],
            ious: (try? context.fetch(FetchDescriptor<IOUModel>())) ?? [],
            fixedCosts: (try? context.fetch(FetchDescriptor<FixedCostModel>())) ?? [],
            events: (try? context.fetch(FetchDescriptor<EventModel>())) ?? [],
            tags: (try? context.fetch(FetchDescriptor<TagModel>())) ?? [],
            rules: (try? context.fetch(FetchDescriptor<RuleModel>())) ?? [],
            checkpoints: (try? context.fetch(FetchDescriptor<CheckpointModel>())) ?? []
        )
    }

    /// Builds a snapshot from already-fetched models (e.g. `@Query` results in a view).
    init(transactions: [TxModel], friends: [FriendModel], ious: [IOUModel], fixedCosts: [FixedCostModel],
         events: [EventModel], tags: [TagModel], rules: [RuleModel] = [], checkpoints: [CheckpointModel]) {
        self.transactions = transactions.map(\.record).sorted { $0.date < $1.date }
        self.friends = friends.map(\.friend)
        self.ious = ious.map(\.iou)
        self.fixedCosts = fixedCosts.map(\.fixedCost)
        self.events = events.map(\.event)
        self.tags = tags.map(\.dayTag)
        self.rules = rules.map(\.rule)
        checkpoint = checkpoints.max { $0.date < $1.date }?.checkpoint
    }

    init() {}

    var categorizer: RulesCategorizer {
        RulesCategorizer(rules: RulesCategorizer.withDefaults().rules + rules)
    }

    /// Credits big enough to be a top-up, plus the user-confirmed last top-up.
    var topUpDates: [Date] {
        var dates = transactions
            .filter { $0.kind == .income && $0.friendID == nil && $0.amount >= Money(rupees: 1000) }
            .map(\.date)
        if let last = AppSettings.lastTopUp { dates.append(last) }
        return dates.sorted()
    }

    var tagsByDay: [Date: Set<String>] {
        var out: [Date: Set<String>] = [:]
        for t in tags { out[t.day, default: []].insert(t.tag) }
        for e in events { if let tag = e.tag { out[IST.startOfDay(e.date), default: []].insert(tag.lowercased()) } }
        return out
    }
}
