import AppIntents
import Foundation
import SpendCore

/// Action Button entry point: cash spend, friend paid, or I paid for the group.
struct QuickLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Log"
    static let description = IntentDescription("Log cash, a bill a friend covered, or a bill you paid for the group.")

    @Parameter(title: "Type", requestValueDialog: "What happened?")
    var mode: QuickLogMode

    @Parameter(title: "Amount", description: "Total bill in rupees", requestValueDialog: "How much was it in total?")
    var amount: Double

    @Parameter(title: "Category", requestValueDialog: "What was it for?")
    var category: CategoryOption

    @Parameter(title: "Friend who paid", requestValueDialog: "Who paid?")
    var payer: FriendEntity?

    @Parameter(title: "Friends to split with", requestValueDialog: "Who were you with?")
    var friends: [FriendEntity]?

    @Parameter(title: "People including you", requestValueDialog: "How many people split it, including you?",
               inclusiveRange: (1, 50))
    var people: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$mode) of ₹\(\.$amount) for \(\.$category)") {
            \.$payer
            \.$friends
            \.$people
        }
    }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = SpendService(context: SharedStore.container.mainContext)
        let total = Money(paise: Int((amount * 100).rounded()))
        guard total.isPositive else { return .result(dialog: "Nothing logged: the amount was zero.") }

        switch mode {
        case .cash:
            service.logCash(amount: total, category: category.rawValue)
            return .result(dialog: "Logged \(total.formatted()) cash for \(category.rawValue).")

        case .friendPaid:
            var who = payer
            if who == nil {
                let requested: FriendEntity? = try await $payer.requestValue()
                who = requested
            }
            guard let who else { throw QuickLogError.missingFriend }
            let n = try await resolvedPeople()
            service.logFriendPaid(friendID: who.id, total: total, people: n, myShare: nil, category: category.rawValue)
            let share = SplitCalculator.friendPaid(total: total, people: n)
            return .result(dialog: "You owe \(who.name) \(share.formatted()). Safe-to-spend updated.")

        case .paidForGroup:
            var group = friends ?? []
            if group.isEmpty {
                let requested: [FriendEntity]? = try await $friends.requestValue()
                group = requested ?? []
            }
            guard !group.isEmpty else { throw QuickLogError.missingFriend }
            let n = try await resolvedPeople()
            service.logPaidForGroup(total: total, friendIDs: group.map(\.id), people: max(n, group.count + 1),
                                    myShare: nil, category: category.rawValue)
            let names = group.map(\.name).formatted()
            return .result(dialog: "Split \(total.formatted()) with \(names). They owe you their shares.")
        }
    }

    @MainActor
    private func resolvedPeople() async throws -> Int {
        if let people { return people }
        let requested: Int? = try await $people.requestValue()
        return max(1, requested ?? 2)
    }
}

enum QuickLogError: Error, CustomLocalizedStringResourceConvertible {
    case missingFriend

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .missingFriend: "Pick at least one friend. Add friends in the Spendwise app first."
        }
    }
}
