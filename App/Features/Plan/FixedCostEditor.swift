import SpendCore
import SwiftData
import SwiftUI

struct FixedCostEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let cost: FixedCostModel?

    @State private var name: String
    @State private var amount: Double?
    @State private var monthly: Bool
    @State private var day: Int
    @State private var date: Date
    @State private var keyword: String

    init(cost: FixedCostModel?) {
        self.cost = cost
        _name = State(initialValue: cost?.name ?? "")
        _amount = State(initialValue: cost.map { Double($0.amountPaise) / 100 })
        _monthly = State(initialValue: cost?.monthlyDay != nil || cost == nil)
        _day = State(initialValue: cost?.monthlyDay ?? IST.dayOfMonth(.now))
        _date = State(initialValue: cost?.onceDate ?? .now)
        _keyword = State(initialValue: cost?.payeeKeyword ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Jio recharge", text: $name)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Toggle("Repeats monthly", isOn: $monthly)
                    if monthly {
                        Stepper("Due on day \(day)", value: $day, in: 1...31)
                    } else {
                        DatePicker("Due", selection: $date, displayedComponents: .date)
                    }
                }
                Section {
                    TextField("e.g. jio", text: $keyword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Payee keyword")
                } footer: {
                    Text("When an SMS payee contains this and the amount matches, the cost is marked paid.")
                }
            }
            .navigationTitle(cost == nil ? "New Fixed Cost" : "Edit Fixed Cost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.isEmpty || (amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let money = Money(paise: Int(((amount ?? 0) * 100).rounded()))
        let target = cost ?? FixedCostModel(name: name, amount: money)
        target.name = name
        target.amountPaise = money.paise
        target.monthlyDay = monthly ? day : nil
        target.onceDate = monthly ? nil : date
        target.payeeKeyword = keyword.isEmpty ? nil : keyword.lowercased()
        if cost == nil { context.insert(target) }
        SpendService(context: context).commit()
        dismiss()
    }
}
