import SpendCore
import SwiftUI

/// Things that make the safe-to-spend number less trustworthy until handled.
struct AttentionSection: View {
    @Environment(AppRouter.self) private var router
    let summary: BudgetSummary
    let reviewItems: [TxModel]
    let unparsedCount: Int
    let lastCheckpoint: Date?

    var body: some View {
        if hasItems {
            Section("Needs attention") {
                if summary.breakdown?.topUpStale == true {
                    Button { router.tab = .plan } label: {
                        Label("Set your next top-up date", systemImage: "calendar.badge.exclamationmark")
                    }
                }
                ForEach(reviewItems.prefix(5)) { tx in
                    NavigationLink {
                        TransactionDetailView(transaction: tx)
                    } label: {
                        Label(reviewTitle(tx), systemImage: tx.needsReview ? "person.crop.circle.badge.questionmark" : "tag")
                    }
                }
                if unparsedCount > 0 {
                    NavigationLink {
                        UnparsedView()
                    } label: {
                        Label("^[\(unparsedCount) unparsed SMS](inflect: true)", systemImage: "exclamationmark.bubble")
                    }
                }
                if checkpointIsOld {
                    Button { router.sheet = .checkpoint } label: {
                        Label("Confirm your bank balance", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
    }

    private var hasItems: Bool {
        summary.breakdown?.topUpStale == true || !reviewItems.isEmpty || unparsedCount > 0 || checkpointIsOld
    }

    /// Weekly reconciliation catches automations that silently stopped firing.
    private var checkpointIsOld: Bool {
        guard let lastCheckpoint, summary.breakdown != nil else { return false }
        return IST.days(from: lastCheckpoint, to: .now) >= 7
    }

    private func reviewTitle(_ tx: TxModel) -> String {
        tx.needsReview
            ? "Was \(tx.amount.formatted()) to \(tx.payee ?? "a friend") a settlement?"
            : "Categorise \(tx.amount.formatted()) to \(tx.payee ?? "unknown")"
    }
}
