import SpendCore
import SwiftUI

struct TransactionRow: View {
    let transaction: TxModel
    var friendName: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: Theme.iconSize, height: Theme.iconSize)
                .background(color, in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
                if transaction.needsReview || (transaction.kind == .spend && transaction.category == nil) {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Needs attention")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        transaction.payee?.capitalized ?? transaction.category ?? kindTitle
    }

    private var subtitle: String {
        let time = transaction.date.formatted(date: .omitted, time: .shortened)
        var parts = [kindTitle == "Spend" ? (transaction.category ?? "Uncategorised") : kindTitle]
        if transaction.myShare < transaction.amount, transaction.kind == .spend {
            parts.append("your share \(transaction.myShare.formatted())")
        }
        if let friendName, transaction.kind != .spend { parts.append(friendName) }
        parts.append(time)
        return parts.joined(separator: " · ")
    }

    private var kindTitle: String {
        switch transaction.kind {
        case .spend: "Spend"
        case .friendPaid: "Friend paid"
        case .income: "Money in"
        case .settleOut: "Paid back"
        case .settleIn: "Got paid back"
        case .transfer: transaction.source == .atm ? "ATM → cash" : "Transfer"
        }
    }

    private var symbol: String {
        switch transaction.kind {
        case .spend, .friendPaid: Categories.symbol(for: transaction.category)
        case .income: "arrow.down.circle"
        case .settleOut, .settleIn: "arrow.left.arrow.right.circle"
        case .transfer: transaction.source == .atm ? "banknote" : "arrow.left.arrow.right"
        }
    }

    private var color: Color {
        switch transaction.kind {
        case .spend, .friendPaid: Theme.color(for: transaction.category)
        case .income, .settleIn: .green
        case .settleOut: .blue
        case .transfer: .gray
        }
    }

    private var amountText: String {
        switch transaction.kind {
        case .income, .settleIn: "+\(transaction.amount.formatted())"
        default: transaction.amount.formatted()
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .income, .settleIn: .green
        case .transfer, .settleOut: .secondary
        default: .primary
        }
    }
}
