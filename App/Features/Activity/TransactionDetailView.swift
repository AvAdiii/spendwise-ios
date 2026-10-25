import SpendCore
import SwiftData
import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let transaction: TxModel

    @Query private var ious: [IOUModel]
    @Query private var friends: [FriendModel]
    @Query private var rules: [RuleModel]
    @State private var category: String
    @State private var note: String
    @State private var showSplit = false
    @State private var confirmDelete = false

    init(transaction: TxModel) {
        self.transaction = transaction
        _category = State(initialValue: transaction.category ?? "")
        _note = State(initialValue: transaction.note ?? "")
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.amount.formatted())
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                    Text(transaction.payee ?? "No payee")
                        .font(.headline)
                    Text(transaction.date.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if transaction.needsReview, let friendID = transaction.friendID {
                Section("Settling up?") {
                    let owed = Ledger.balances(ious.map(\.iou))[friendID]?.payable ?? .zero
                    Text("You owe \(friendName(friendID)) \(owed.formatted()). Was this payment settling that?")
                    Button("Yes, it's a settlement") { service.confirmSettlement(transactionID: transaction.id) }
                    Button("No, it's my spending") { service.dismissReview(transactionID: transaction.id) }
                }
            }

            if transaction.kind == .spend || transaction.kind == .friendPaid {
                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("Uncategorised").tag("")
                        ForEach(categories, id: \.self) { name in
                            Label(name, systemImage: Categories.symbol(for: name)).tag(name)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            if transaction.kind == .spend {
                Section {
                    if !splitIOUs.isEmpty {
                        LabeledContent("Your share", value: transaction.myShare.formatted())
                        ForEach(splitIOUs) { iou in
                            LabeledContent(friendName(iou.friendID), value: Money(paise: iou.amountPaise).formatted())
                        }
                    }
                    Button(splitIOUs.isEmpty ? "Split with friends" : "Edit split", systemImage: "person.2") { showSplit = true }
                } header: {
                    Text("Split")
                } footer: {
                    Text("Only your share counts as spending. The rest is owed to you.")
                }
            }

            if transaction.source == .upi, transaction.kind == .spend || transaction.kind == .transfer {
                Section {
                    if transaction.kind == .spend {
                        Button("Not spending (transfer to myself)", systemImage: "arrow.left.arrow.right") {
                            service.markTransfer(transactionID: transaction.id)
                        }
                    } else {
                        Button("Count as spending", systemImage: "cart") {
                            service.markSpend(transactionID: transaction.id)
                        }
                    }
                }
            }

            Section("Note") {
                TextField("Add a note", text: $note, axis: .vertical)
                    .onSubmit { service.updateNote(transactionID: transaction.id, note: note) }
            }

            if let raw = transaction.rawSMS {
                Section("Original SMS") {
                    Text(raw)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section {
                Button("Delete transaction", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(transaction.kind == .spend ? "Spend" : "Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: category) { _, newValue in
            guard !newValue.isEmpty, newValue != transaction.category else { return }
            service.setCategory(transactionID: transaction.id, category: newValue)
        }
        .onDisappear {
            if note != (transaction.note ?? "") { service.updateNote(transactionID: transaction.id, note: note) }
        }
        .sheet(isPresented: $showSplit) {
            SplitSheet(transaction: transaction)
        }
        .confirmationDialog("Delete this transaction?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                service.delete(transactionID: transaction.id)
                dismiss()
            }
        } message: {
            Text("Any IOUs created by splitting it are removed too.")
        }
    }

    private var service: SpendService { SpendService(context: context) }

    private var splitIOUs: [IOUModel] {
        ious.filter { $0.sourceTxID == transaction.id && $0.direction == .theyOwe }
    }

    private var categories: [String] {
        Array(Set(Categories.defaults + rules.map(\.category))).sorted()
    }

    private func friendName(_ id: UUID) -> String {
        friends.first { $0.id == id }?.name ?? "Friend"
    }
}
