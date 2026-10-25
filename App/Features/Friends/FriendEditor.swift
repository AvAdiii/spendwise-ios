import SpendCore
import SwiftData
import SwiftUI

struct FriendEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TxModel.date, order: .reverse) private var transactions: [TxModel]
    let friend: FriendModel?

    @State private var name: String
    @State private var aliases: [String]
    @State private var newAlias = ""
    @State private var vpa: String
    @State private var confirmDelete = false

    init(friend: FriendModel?) {
        self.friend = friend
        _name = State(initialValue: friend?.name ?? "")
        _aliases = State(initialValue: friend?.aliases ?? [])
        _vpa = State(initialValue: friend?.vpa ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                }

                Section {
                    ForEach(aliases, id: \.self) { Text($0) }
                        .onDelete { aliases.remove(atOffsets: $0) }
                    HStack {
                        TextField("e.g. PRIYA SHARMA", text: $newAlias)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onSubmit(addAlias)
                        Button("Add", action: addAlias)
                            .disabled(newAlias.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(suggestions, id: \.self) { payee in
                                    Button(payee) { aliases.append(payee) }
                                        .buttonStyle(.bordered)
                                        .font(.footnote)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                } header: {
                    Text("Names in bank SMS")
                } footer: {
                    Text("Exactly as written after \"trf to\" in your SBI alerts. Recent payees are suggested above.")
                }

                Section {
                    TextField("name@okaxis", text: $vpa)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("UPI ID (optional)")
                } footer: {
                    Text("Lets you pay them back from the app.")
                }

                if friend != nil {
                    Section {
                        Button("Delete friend", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(friend == nil ? "New Friend" : "Edit Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \(name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let friend { SpendService(context: context).deleteFriend(friend.id) }
                    dismiss()
                }
            } message: {
                Text("Their IOUs are deleted too. Transactions stay.")
            }
        }
    }

    /// Person-like payees from recent unmatched, uncategorised debits.
    private var suggestions: [String] {
        var seen = Set(aliases)
        return transactions.prefix(200).compactMap { tx -> String? in
            guard tx.friendID == nil, tx.category == nil, tx.source == .upi, let payee = tx.payee,
                  seen.insert(payee).inserted else { return nil }
            return payee
        }
        .prefix(8)
        .map { $0 }
    }

    private func addAlias() {
        let a = newAlias.trimmingCharacters(in: .whitespaces).uppercased()
        guard !a.isEmpty, !aliases.contains(a) else { return }
        aliases.append(a)
        newAlias = ""
    }

    private func save() {
        addAlias()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let target = friend ?? FriendModel(name: trimmedName)
        target.name = trimmedName
        target.aliases = aliases
        target.vpa = vpa.isEmpty ? nil : vpa.trimmingCharacters(in: .whitespaces)
        if friend == nil { context.insert(target) }
        SpendService(context: context).commit()
        dismiss()
    }
}
