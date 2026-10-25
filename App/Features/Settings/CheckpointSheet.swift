import SpendCore
import SwiftData
import SwiftUI

/// Confirms the real balance; the gap against the computed one reveals missed SMS.
struct CheckpointSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var bank: Double?
    @State private var cash: Double?

    var body: some View {
        let computed = BudgetSummary.compute(LedgerSnapshot.load(from: context)).breakdown
        NavigationStack {
            Form {
                Section {
                    TextField("Bank balance", value: $bank, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Cash in hand", value: $cash, format: .number)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text("Check the SBI YONO app or BHIM for your exact bank balance.")
                }
                if let computed {
                    Section("Spendwise thinks") {
                        LabeledContent("Bank", value: computed.bank.formatted())
                        LabeledContent("Cash", value: computed.cash.formatted())
                        if let bank {
                            let gap = Money(paise: Int((bank * 100).rounded())) - computed.bank
                            if abs(gap.paise) >= 100 {
                                Label("Off by \(gap.formatted()). An SMS may not have been captured.",
                                      systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(bank == nil)
                }
            }
            .onAppear {
                if cash == nil, let computed { cash = computed.cash.rupees }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        SpendService(context: context).recordCheckpoint(
            bank: Money(paise: Int(((bank ?? 0) * 100).rounded())),
            cash: Money(paise: Int(((cash ?? 0) * 100).rounded()))
        )
        dismiss()
    }
}
