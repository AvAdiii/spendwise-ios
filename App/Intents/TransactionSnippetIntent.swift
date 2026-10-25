import AppIntents
import SpendCore
import SwiftData
import SwiftUI

/// Interactive snippet shown after an SMS is logged. Its buttons run intents and the snippet refreshes.
struct TransactionSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Logged Transaction"
    static let isDiscoverable = false

    @Parameter(title: "Transaction ID")
    var transactionID: String

    @Parameter(title: "Status")
    var status: String

    init() {}

    init(transactionID: String, status: String) {
        self.transactionID = transactionID
        self.status = status
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let context = SharedStore.container.mainContext
        let service = SpendService(context: context)
        let tx = UUID(uuidString: transactionID).flatMap(service.transaction)
        let snapshot = LedgerSnapshot.load(from: context)
        let summary = BudgetSummary.compute(snapshot)
        var owed: Money?
        var friendName: String?
        if let tx, tx.needsReview, let friendID = tx.friendID {
            owed = Ledger.balances(snapshot.ious)[friendID]?.payable
            friendName = service.friend(friendID)?.name
        }
        return .result(view: TransactionSnippetView(
            transaction: tx.map(SnippetTransaction.init), status: status, owed: owed, friendName: friendName,
            leftToday: summary.breakdown?.leftToday
        ))
    }
}

struct SnippetTransaction {
    var id: UUID
    var amount: Money
    var payee: String
    var category: String?
    var kind: TxKind
    var myShare: Money

    init(_ m: TxModel) {
        id = m.id
        amount = m.amount
        payee = m.payee ?? m.category ?? "Transaction"
        category = m.category
        kind = m.kind
        myShare = m.myShare
    }
}

struct TransactionSnippetView: View {
    let transaction: SnippetTransaction?
    let status: String
    let owed: Money?
    let friendName: String?
    let leftToday: Money?

    private let quickCategories = ["Food", "Groceries", "Transport", "Shopping", "Entertainment", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tx = transaction {
                header(tx)
                if let owed, let friendName {
                    Text("Is this settling the \(owed.formatted()) you owe \(friendName)?")
                        .font(.subheadline)
                    HStack {
                        Button(intent: ConfirmSettlementIntent(transactionID: tx.id.uuidString)) {
                            Label("Yes, settle", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        Button(intent: DismissReviewIntent(transactionID: tx.id.uuidString)) {
                            Text("No, spending")
                        }
                        .buttonStyle(.bordered)
                    }
                } else if tx.kind == .spend {
                    categoryChips(tx)
                    HStack {
                        Button(intent: OpenSplitIntent(transactionID: tx.id.uuidString)) {
                            Label("Split", systemImage: "person.2")
                        }
                        Button(intent: MarkTransferIntent(transactionID: tx.id.uuidString)) {
                            Label("Not spending", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.subheadline)
                }
                if let leftToday {
                    Text("Safe to spend today: \(leftToday.formatted())")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label(statusMessage, systemImage: status == "duplicate" ? "checkmark.circle" : "exclamationmark.bubble")
                    .font(.headline)
            }
        }
        .padding()
    }

    private func header(_ tx: SnippetTransaction) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(tx.payee).font(.headline)
                Text(subtitle(tx)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(tx.amount.formatted()).font(.title2.bold()).monospacedDigit()
        }
    }

    private func subtitle(_ tx: SnippetTransaction) -> String {
        switch tx.kind {
        case .settleOut: "Settled with a friend"
        case .settleIn: "Friend paid you back"
        case .income: "Money in"
        case .transfer: "Transfer, not spending"
        default:
            tx.myShare < tx.amount ? "\(tx.category ?? "Uncategorised") · your share \(tx.myShare.formatted())" : tx.category ?? "Pick a category"
        }
    }

    private func categoryChips(_ tx: SnippetTransaction) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { chips(tx) }
            VStack(alignment: .leading) {
                HStack { chips(tx, range: 0..<3) }
                HStack { chips(tx, range: 3..<quickCategories.count) }
            }
        }
    }

    @ViewBuilder
    private func chips(_ tx: SnippetTransaction, range: Range<Int>? = nil) -> some View {
        let names = Array(quickCategories[range ?? 0..<quickCategories.count])
        ForEach(names, id: \.self) { name in
            Button(intent: SetCategoryIntent(transactionID: tx.id.uuidString, category: name)) {
                Image(systemName: Categories.symbol(for: name))
                    .accessibilityLabel(name)
            }
            .buttonStyle(.bordered)
            .tint(tx.category == name ? Theme.color(for: name) : .secondary)
        }
    }

    private var statusMessage: String {
        switch status {
        case "duplicate": "Already logged"
        case "unparsed": "Couldn't read this SMS. Saved under Settings › Unparsed."
        default: "Logged"
        }
    }
}
