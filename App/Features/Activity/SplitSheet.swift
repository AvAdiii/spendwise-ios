import SpendCore
import SwiftData
import SwiftUI

/// Opened from the SMS snippet's Split button via `AppSheet.split`.
struct SplitSheetLoader: View {
    @Environment(\.modelContext) private var context
    let transactionID: UUID

    var body: some View {
        if let tx = SpendService(context: context).transaction(transactionID) {
            SplitSheet(transaction: tx)
        } else {
            ContentUnavailableView("Transaction not found", systemImage: "questionmark.circle")
        }
    }
}

struct SplitSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case equal = "Split equally"
        case myShare = "Enter my share"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FriendModel.name) private var friends: [FriendModel]
    let transaction: TxModel

    @State private var selected: Set<UUID> = []
    @State private var mode = Mode.equal
    @State private var people = 2
    @State private var myShareRupees: Double?
    @State private var showAddFriend = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Total", value: transaction.amount.formatted())
                    Picker("How", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if mode == .equal {
                        Stepper("\(people) people including you", value: $people, in: max(2, selected.count + 1)...50)
                    } else {
                        TextField("My share", value: $myShareRupees, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    ForEach(friends) { friend in
                        Button {
                            toggle(friend.id)
                        } label: {
                            HStack {
                                Text(friend.name).foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(friend.id) {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityAddTraits(selected.contains(friend.id) ? .isSelected : [])
                    }
                    Button("Add a friend", systemImage: "person.badge.plus") { showAddFriend = true }
                } header: {
                    Text("Who owes you")
                } footer: {
                    if let preview { Text(preview) }
                }
            }
            .navigationTitle("Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(selected.isEmpty)
                }
            }
            .sheet(isPresented: $showAddFriend) {
                FriendEditor(friend: nil)
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var myShare: Money? {
        guard mode == .myShare, let myShareRupees else { return nil }
        return Money(paise: Int((myShareRupees * 100).rounded()))
    }

    private var preview: String? {
        guard !selected.isEmpty else { return nil }
        let result = SplitCalculator.paidForGroup(total: transaction.amount, people: mode == .equal ? people : nil,
                                                  myShare: myShare, friends: Array(selected))
        let each = result.friendShares.values.first ?? .zero
        return "Your share \(result.myShare.formatted()). Each friend owes \(each.formatted())."
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        people = max(people, selected.count + 1)
    }

    private func loadExisting() {
        let txID: UUID? = transaction.id
        let existing = (try? context.fetch(FetchDescriptor<IOUModel>(predicate: #Predicate { $0.sourceTxID == txID }))) ?? []
        selected = Set(existing.map(\.friendID))
        people = max(2, selected.count + 1)
    }

    private func save() {
        SpendService(context: context).split(transactionID: transaction.id, friendIDs: Array(selected),
                                             people: mode == .equal ? people : nil, myShare: myShare)
        dismiss()
    }
}
