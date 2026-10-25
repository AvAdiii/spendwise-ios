import SpendCore
import SwiftData
import SwiftUI

struct QuickLogSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FriendModel.name) private var friends: [FriendModel]

    @State private var mode: QuickLogMode
    @State private var amount: Double?
    @State private var category = "Food"
    @State private var payer: UUID?
    @State private var group: Set<UUID> = []
    @State private var people = 2
    @State private var note = ""
    @State private var showAddFriend = false
    @FocusState private var amountFocused: Bool

    init(initialMode: QuickLogMode) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $mode) {
                        ForEach(QuickLogMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField(mode == .cash ? "Amount" : "Total bill", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.title.bold())
                        .focused($amountFocused)
                }

                Section("Category") {
                    CategoryGrid(selection: $category)
                }

                if mode == .friendPaid {
                    Section("Who paid?") {
                        Picker("Friend", selection: $payer) {
                            Text("Choose").tag(UUID?.none)
                            ForEach(friends) { Text($0.name).tag(Optional($0.id)) }
                        }
                        Stepper("\(people) people including you", value: $people, in: 1...50)
                        addFriendButton
                    }
                }

                if mode == .paidForGroup {
                    Section {
                        ForEach(friends) { friend in
                            Toggle(friend.name, isOn: membership(friend.id))
                        }
                        Stepper("\(people) people including you", value: $people, in: max(2, group.count + 1)...50)
                        addFriendButton
                    } header: {
                        Text("Who was there?")
                    } footer: {
                        Text("If this was paid by UPI in the last 20 minutes, the split attaches to that SMS transaction.")
                    }
                }

                Section {
                    TextField("Note (optional)", text: $note)
                } footer: {
                    if let summary { Text(summary) }
                }
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log", action: save).disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAddFriend) {
                FriendEditor(friend: nil)
            }
            .onAppear { amountFocused = true }
        }
    }

    private var addFriendButton: some View {
        Button("Add a friend", systemImage: "person.badge.plus") { showAddFriend = true }
    }

    private func membership(_ id: UUID) -> Binding<Bool> {
        Binding {
            group.contains(id)
        } set: { isOn in
            if isOn { group.insert(id) } else { group.remove(id) }
            people = max(people, group.count + 1)
        }
    }

    private var total: Money {
        Money(paise: Int(((amount ?? 0) * 100).rounded()))
    }

    private var canSave: Bool {
        guard total.isPositive else { return false }
        switch mode {
        case .cash: return true
        case .friendPaid: return payer != nil
        case .paidForGroup: return !group.isEmpty
        }
    }

    private var summary: String? {
        guard total.isPositive else { return nil }
        switch mode {
        case .cash:
            return nil
        case .friendPaid:
            let share = SplitCalculator.friendPaid(total: total, people: people)
            return "You'll owe \(share.formatted()). It counts against today's budget right away."
        case .paidForGroup:
            guard !group.isEmpty else { return nil }
            let r = SplitCalculator.paidForGroup(total: total, people: people, friends: Array(group))
            return "Your share \(r.myShare.formatted()); \(group.count) friends owe you \(r.friendShares.values.sum().formatted())."
        }
    }

    private func save() {
        let service = SpendService(context: context)
        let noteValue = note.isEmpty ? nil : note
        switch mode {
        case .cash:
            service.logCash(amount: total, category: category, note: noteValue)
        case .friendPaid:
            guard let payer else { return }
            service.logFriendPaid(friendID: payer, total: total, people: people, myShare: nil, category: category, note: noteValue)
        case .paidForGroup:
            service.logPaidForGroup(total: total, friendIDs: Array(group), people: people, myShare: nil,
                                    category: category, note: noteValue)
        }
        dismiss()
    }
}
