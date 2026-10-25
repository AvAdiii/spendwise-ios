import AppIntents
import Foundation

struct SafeToSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Safe to Spend"
    static let description = IntentDescription("Tells you how much you can spend today without running out before your next top-up.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let summary = BudgetSummary.compute(LedgerSnapshot.load(from: SharedStore.container.mainContext))
        guard let b = summary.breakdown else {
            return .result(value: 0, dialog: "Open Spendwise and set your balance first.")
        }
        return .result(value: b.leftToday.rupees,
                       dialog: "You can spend \(b.leftToday.formatted()) today. \(summary.runOutText).")
    }
}
