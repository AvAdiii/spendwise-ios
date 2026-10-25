import SpendCore
import SwiftData
import SwiftUI

struct EventEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var date = IST.addDays(1, to: .now)
    @State private var estimate: Double?
    @State private var tag = "party"

    static let tags = ["party", "club", "travel", "fest", "exam", "holiday"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. House party", text: $name)
                    DatePicker("When", selection: $date, in: IST.startOfDay(.now)..., displayedComponents: .date)
                    Picker("Kind", selection: $tag) {
                        ForEach(Self.tags, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section {
                    TextField("Estimated cost", value: $estimate, format: .number)
                        .keyboardType(.decimalPad)
                } footer: {
                    if let typical { Text("Days tagged \(tag) usually add about \(typical.formatted()).") }
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.isEmpty)
                }
            }
        }
    }

    /// What the forecast has learned this tag costs, when it knows.
    private var typical: Money? {
        let model = BudgetSummary.compute(LedgerSnapshot.load(from: context)).model
        guard model.knownTags.contains(tag) else { return nil }
        let extra = model.tagExtraCost(tag, on: [date])
        return extra.isPositive ? extra : nil
    }

    private func save() {
        let entered = Money(paise: Int(((estimate ?? 0) * 100).rounded()))
        let money = entered.isPositive ? entered : typical ?? .zero
        context.insert(EventModel(name: name, date: IST.startOfDay(date), estimate: money, tag: tag))
        SpendService(context: context).commit()
        dismiss()
    }
}
