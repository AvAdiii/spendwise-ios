import SpendCore
import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var vpa = ""
    @State private var bank: Double?
    @State private var cash: Double?
    @State private var nextTopUp = IST.addDays(14, to: IST.startOfDay(.now))

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("One honest number")
                            .font(.title2.bold())
                        Text("Spendwise shows how much you can spend today without running out before your next top-up, counting what you owe friends.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Right now") {
                    TextField("Bank balance (₹)", value: $bank, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Cash in hand (₹)", value: $cash, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Next top-up", selection: $nextTopUp, in: IST.addDays(1, to: .now)..., displayedComponents: .date)
                }

                Section {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                    TextField("Your UPI ID (for request links)", text: $vpa)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Optional")
                }
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: start).disabled(bank == nil)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func start() {
        AppSettings.userName = name
        AppSettings.userVPA = vpa.trimmingCharacters(in: .whitespaces)
        AppSettings.nextTopUp = nextTopUp
        AppSettings.lastTopUp = .now
        AppSettings.onboarded = true
        SpendService(context: context).recordCheckpoint(
            bank: Money(paise: Int(((bank ?? 0) * 100).rounded())),
            cash: Money(paise: Int(((cash ?? 0) * 100).rounded()))
        )
        Task { _ = await AlertScheduler.shared.requestAuthorization() }
        dismiss()
    }
}
