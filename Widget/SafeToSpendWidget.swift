import SpendCore
import SwiftUI
import WidgetKit

struct SafeToSpendWidget: Widget {
    let kind = "SafeToSpend"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendProvider()) { entry in
            SafeToSpendWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Safe to Spend")
        .description("How much you can spend today without running out before your next top-up.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct SafeToSpendWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpendEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.leftToday.map { "\($0.formatted()) safe today" } ?? "Spendwise")
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var tint: Color {
        guard let left = entry.leftToday else { return .secondary }
        if left < .zero { return .red }
        if entry.allowance.isPositive, left.paise * 4 < entry.allowance.paise { return .orange }
        return .green
    }

    private var amount: String { entry.leftToday?.formatted() ?? "—" }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Safe today")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.system(.title, design: .rounded).bold())
                .monospacedDigit()
                .foregroundStyle(tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(entry.leftToday == nil ? entry.runOutText : "\(entry.daysLeft) days to top-up")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "spendwise://tab/today"))
    }

    private var medium: some View {
        HStack(alignment: .top) {
            small
            VStack(alignment: .leading, spacing: 6) {
                Label(entry.runOutText, systemImage: entry.isRunningOut ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(entry.isRunningOut ? .orange : .green)
                if entry.payable.isPositive {
                    Text("You owe \(entry.payable.formatted())").font(.caption)
                }
                if entry.receivable.isPositive {
                    Text("Owed \(entry.receivable.formatted())").font(.caption)
                }
                Spacer(minLength: 0)
                if let url = URL(string: "spendwise://quicklog/cash") {
                    Link(destination: url) {
                        Label("Log cash", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading) {
            Text("Safe today").font(.caption)
            Text(amount).font(.headline).monospacedDigit()
            Text(entry.runOutText).font(.caption).lineLimit(1)
        }
    }

    private var circular: some View {
        Gauge(value: gaugeValue) {
            Image(systemName: "indianrupeesign")
        } currentValueLabel: {
            Text(entry.leftToday.map { "\(max(0, $0.paise / 100))" } ?? "—")
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var gaugeValue: Double {
        guard let left = entry.leftToday, entry.allowance.isPositive else { return 0 }
        return min(1, max(0, Double(left.paise) / Double(entry.allowance.paise)))
    }
}

#Preview(as: .systemSmall) {
    SafeToSpendWidget()
} timeline: {
    SpendEntry.sample
}
