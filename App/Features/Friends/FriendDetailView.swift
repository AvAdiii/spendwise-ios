import SpendCore
import SwiftData
import SwiftUI

struct FriendDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    let friend: FriendModel

    @Query(sort: \IOUModel.createdAt, order: .reverse) private var allIOUs: [IOUModel]
    @State private var showEdit = false
    @State private var settleDirection: IOUDirection?

    var body: some View {
        let balance = Ledger.balances(ious.map(\.iou))[friend.id] ?? FriendBalance(payable: .zero, receivable: .zero)
        List {
            Section {
                LabeledContent("Owes you", value: balance.receivable.formatted())
                LabeledContent("You owe", value: balance.payable.formatted())
            }

            if balance.receivable.isPositive {
                Section {
                    if let link = requestLink(amount: balance.receivable) {
                        ShareLink(item: requestMessage(amount: balance.receivable, link: link)) {
                            Label("Request \(balance.receivable.formatted())", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Label("Add your UPI ID in Settings to send request links.", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    Button("Mark as received…", systemImage: "checkmark.circle") { settleDirection = .theyOwe }
                } footer: {
                    Text("When their payment SMS arrives, Spendwise settles this automatically.")
                }
            }

            if balance.payable.isPositive {
                Section {
                    if let vpa = friend.vpa, !vpa.isEmpty,
                       let url = UPILinkBuilder.payLink(vpa: vpa, name: friend.name, amount: balance.payable, note: "Settle up") {
                        Button("Pay \(balance.payable.formatted()) by UPI", systemImage: "indianrupeesign.circle") { openURL(url) }
                    }
                    Button("Mark as paid…", systemImage: "checkmark.circle") { settleDirection = .iOwe }
                } footer: {
                    Text("Paying \(friend.name) the exact amount by UPI closes this from the SMS.")
                }
            }

            let open = ious.filter(\.iou.isOpen)
            if !open.isEmpty {
                Section("Open") {
                    ForEach(open) { IOURow(iou: $0) }
                }
            }
            let closed = ious.filter { !$0.iou.isOpen }
            if !closed.isEmpty {
                Section("Settled") {
                    ForEach(closed.prefix(20)) { IOURow(iou: $0) }
                }
            }
        }
        .navigationTitle(friend.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            FriendEditor(friend: friend)
        }
        .confirmationDialog("Settle up", isPresented: settleBinding, titleVisibility: .visible, presenting: settleDirection) { direction in
            let amount = direction == .iOwe ? balance.payable : balance.receivable
            ForEach(SpendService.SettleMethod.allCases) { method in
                Button(method.title) {
                    SpendService(context: context).settle(friendID: friend.id, amount: amount, direction: direction, method: method)
                }
            }
        } message: { direction in
            Text(direction == .iOwe ? "How did you pay \(friend.name)?" : "How did \(friend.name) pay you?")
        }
    }

    private var ious: [IOUModel] {
        allIOUs.filter { $0.friendID == friend.id }
    }

    private var settleBinding: Binding<Bool> {
        Binding { settleDirection != nil } set: { if !$0 { settleDirection = nil } }
    }

    private func requestLink(amount: Money) -> URL? {
        let vpa = AppSettings.userVPA
        guard !vpa.isEmpty else { return nil }
        let name = AppSettings.userName.isEmpty ? "Spendwise" : AppSettings.userName
        return UPILinkBuilder.payLink(vpa: vpa, name: name, amount: amount, note: "Settle up")
    }

    private func requestMessage(amount: Money, link: URL) -> String {
        "Hey \(friend.name)! You owe me \(amount.formatted()). Tap to pay: \(link.absoluteString)"
    }
}

struct IOURow: View {
    let iou: IOUModel

    var body: some View {
        let value = iou.iou
        HStack {
            VStack(alignment: .leading) {
                Text(iou.note ?? (iou.direction == .iOwe ? "You owe" : "They owe"))
                Text(iou.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value.isOpen ? value.outstanding.formatted() : value.amount.formatted())
                .monospacedDigit()
                .foregroundStyle(value.isOpen ? (iou.direction == .iOwe ? .orange : .green) : .secondary)
                .strikethrough(!value.isOpen)
        }
    }
}
