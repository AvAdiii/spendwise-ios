import SpendCore
import SwiftUI

struct BreakdownSheet: View {
    @Environment(\.dismiss) private var dismiss
    let summary: BudgetSummary

    var body: some View {
        NavigationStack {
            List {
                if let b = summary.breakdown {
                    Section {
                        row("Bank", b.bank)
                        row("Cash", b.cash)
                        row("You have", b.liquid, bold: true)
                    }
                    Section {
                        row("Owed to friends", -b.payables)
                        row("Fixed costs before top-up", -b.fixedDue)
                        row("Planned events", -b.eventsDue)
                        row("Available", b.available, bold: true)
                    } footer: {
                        Text("Money friends owe you (\(b.receivables.formatted())) isn't counted until it arrives.")
                    }
                    Section {
                        LabeledContent("Days until top-up", value: "\(b.daysLeft)")
                        row("Daily allowance", b.dailyAllowance)
                        row("Spent today", -b.spentToday)
                        row("Left today", b.leftToday, bold: true)
                    }
                    Section("Forecast") {
                        LabeledContent("Model", value: modelName)
                        LabeledContent("Expected today", value: summary.model.expected(on: .now).formatted())
                        Text(summary.runOutText)
                    }
                }
            }
            .navigationTitle("Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, _ value: Money, bold: Bool = false) -> some View {
        LabeledContent {
            Text(value.formatted()).monospacedDigit()
        } label: {
            Text(title)
        }
        .bold(bold)
    }

    private var modelName: String {
        switch summary.model.mode {
        case .noData: "Not enough data"
        case .pace: "Recent pace (\(summary.model.historyDays) days)"
        case .baseline: "Patterns from \(summary.model.historyDays) days"
        }
    }
}
