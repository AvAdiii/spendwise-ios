import SpendCore
import SwiftData
import SwiftUI

struct ActivityView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case review = "Needs attention"
        case spending = "Spending"
        case moneyIn = "Money in"
        case friends = "With friends"
        var id: String { rawValue }
    }

    @Query(sort: \TxModel.date, order: .reverse) private var transactions: [TxModel]
    @Query private var friends: [FriendModel]
    @State private var search = ""
    @State private var filter = Filter.all

    var body: some View {
        NavigationStack {
            List {
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.items) { tx in
                            NavigationLink {
                                TransactionDetailView(transaction: tx)
                            } label: {
                                TransactionRow(transaction: tx, friendName: friendName(tx.friendID))
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.day.formatted(.dateTime.weekday(.wide).day().month()))
                            Spacer()
                            Text(group.spent.formatted()).monospacedDigit()
                        }
                    }
                }
            }
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView("No transactions yet", systemImage: "tray",
                                           description: Text("Set up the SMS automation in Settings, or log one with +."))
                } else if days.isEmpty {
                    ContentUnavailableView.search
                }
            }
            .searchable(text: $search, prompt: "Payee, category or note")
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Filter", systemImage: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") {
                        Picker("Filter", selection: $filter) {
                            ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                }
            }
        }
    }

    private struct DayGroup {
        var day: Date
        var items: [TxModel]
        var spent: Money { items.map(\.record.spending).sum() }
    }

    private var days: [DayGroup] {
        let filtered = transactions.filter { matches($0) }
        let grouped = Dictionary(grouping: filtered) { IST.startOfDay($0.date) }
        return grouped.map { DayGroup(day: $0.key, items: $0.value) }.sorted { $0.day > $1.day }
    }

    private func matches(_ tx: TxModel) -> Bool {
        let passesFilter = switch filter {
        case .all: true
        case .review: tx.needsReview || (tx.kind == .spend && tx.category == nil)
        case .spending: tx.kind == .spend || tx.kind == .friendPaid
        case .moneyIn: tx.kind == .income || tx.kind == .settleIn
        case .friends: tx.friendID != nil || tx.myShare < tx.amount
        }
        guard passesFilter else { return false }
        guard !search.isEmpty else { return true }
        return [tx.payee, tx.category, tx.note, friendName(tx.friendID)]
            .compactMap { $0 }
            .contains { $0.localizedStandardContains(search) }
    }

    private func friendName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return friends.first { $0.id == id }?.name
    }
}
