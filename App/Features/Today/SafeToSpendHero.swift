import SpendCore
import SwiftUI

struct SafeToSpendHero: View {
    let breakdown: BudgetBreakdown
    let summary: BudgetSummary
    let showBreakdown: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = Theme.heroFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Safe to spend today")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(breakdown.leftToday.formatted())
                .font(.system(size: heroSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.color(left: breakdown.leftToday, allowance: breakdown.dailyAllowance))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("\(breakdown.dailyAllowance.formatted()) a day · \(daysText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(summary.runOutText, systemImage: summary.isRunningOut ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(summary.isRunningOut ? .orange : .green)

            Button("See breakdown", systemImage: "list.bullet.below.rectangle", action: showBreakdown)
                .font(.subheadline)
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical)
        .accessibilityElement(children: .contain)
    }

    private var daysText: String {
        if breakdown.topUpStale { return "set your next top-up date" }
        return breakdown.daysLeft == 1 ? "top-up tomorrow" : "\(breakdown.daysLeft) days to top-up"
    }
}
