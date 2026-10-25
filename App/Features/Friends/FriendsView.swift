import SpendCore
import SwiftData
import SwiftUI

struct FriendsView: View {
    @Query(sort: \FriendModel.name) private var friends: [FriendModel]
    @Query private var ious: [IOUModel]
    @State private var showAdd = false

    var body: some View {
        let balances = Ledger.balances(ious.map(\.iou))
        NavigationStack {
            List {
                if let nudge = CollectionNudge.message(now: .now, receivable: Ledger.totalReceivable(ious.map(\.iou)),
                                                       debtors: balances.values.count(where: { $0.receivable.isPositive }),
                                                       payable: Ledger.totalPayable(ious.map(\.iou))) {
                    Section {
                        Label(nudge, systemImage: "calendar.badge.clock")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Everyone has money in the first days of the month. Send request links now.")
                    }
                }

                Section {
                    ForEach(sorted(balances)) { friend in
                        NavigationLink {
                            FriendDetailView(friend: friend)
                        } label: {
                            FriendRow(name: friend.name, balance: balances[friend.id])
                        }
                    }
                }
            }
            .overlay {
                if friends.isEmpty {
                    ContentUnavailableView {
                        Label("No friends yet", systemImage: "person.2")
                    } description: {
                        Text("Add the friends you split bills with. Their SBI payee name lets Spendwise spot settlements.")
                    } actions: {
                        Button("Add a friend") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Friend", systemImage: "person.badge.plus") { showAdd = true }
                }
            }
            .sheet(isPresented: $showAdd) {
                FriendEditor(friend: nil)
            }
        }
    }

    /// Largest open balance first, settled friends last.
    private func sorted(_ balances: [UUID: FriendBalance]) -> [FriendModel] {
        friends.sorted {
            abs(balances[$0.id]?.net.paise ?? 0) > abs(balances[$1.id]?.net.paise ?? 0)
        }
    }
}

struct FriendRow: View {
    let name: String
    let balance: FriendBalance?

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            if let balance, balance.net.isPositive {
                Text("owes you \(balance.net.formatted())").foregroundStyle(.green)
            } else if let balance, balance.net < .zero {
                Text("you owe \((-balance.net).formatted())").foregroundStyle(.orange)
            } else {
                Text("settled").foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
    }
}
