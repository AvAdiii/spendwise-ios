import SpendCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \TxModel.date, order: .reverse) private var transactions: [TxModel]
    @Query private var friends: [FriendModel]
    @Query private var ious: [IOUModel]
    @Query private var fixedCosts: [FixedCostModel]
    @Query private var events: [EventModel]
    @Query private var tags: [TagModel]
    @Query private var checkpoints: [CheckpointModel]
    @Query private var unparsed: [UnparsedSMSModel]
    @State private var showBreakdown = false

    var body: some View {
        let summary = BudgetSummary.compute(snapshot)
        NavigationStack {
            List {
                Section {
                    if let b = summary.breakdown {
                        SafeToSpendHero(breakdown: b, summary: summary) { showBreakdown = true }
                    } else {
                        SetBalancePrompt { router.sheet = .checkpoint }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                AttentionSection(summary: summary, reviewItems: needsReview, unparsedCount: unparsed.count,
                                 lastCheckpoint: checkpoints.map(\.date).max())

                if let b = summary.breakdown, b.payables.isPositive || b.receivables.isPositive {
                    Section("Friends") {
                        Button { router.tab = .friends } label: {
                            LabeledContent("You owe", value: b.payables.formatted())
                        }
                        Button { router.tab = .friends } label: {
                            LabeledContent("Owed to you", value: b.receivables.formatted())
                        }
                    }
                    .tint(.primary)
                }

                Section("Today") {
                    if todays.isEmpty {
                        Text("Nothing logged yet today.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todays) { tx in
                            NavigationLink {
                                TransactionDetailView(transaction: tx)
                            } label: {
                                TransactionRow(transaction: tx, friendName: friendName(tx.friendID))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Quick Log", systemImage: "plus") { router.sheet = .quickLog(nil) }
                }
            }
            .sheet(isPresented: $showBreakdown) {
                BreakdownSheet(summary: summary)
            }
        }
    }

    private var snapshot: LedgerSnapshot {
        LedgerSnapshot(transactions: transactions, friends: friends, ious: ious, fixedCosts: fixedCosts,
                       events: events, tags: tags, checkpoints: checkpoints)
    }

    private var todays: [TxModel] {
        transactions.filter { IST.isSameDay($0.date, .now) }
    }

    private var needsReview: [TxModel] {
        transactions.filter { $0.needsReview || ($0.kind == .spend && $0.category == nil) }
    }

    private func friendName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return friends.first { $0.id == id }?.name
    }
}

#Preview {
    let container = SharedStore.makeContainer(inMemory: true)
    DemoData.seed(container.mainContext)
    return TodayView()
        .environment(AppRouter.shared)
        .modelContainer(container)
}
