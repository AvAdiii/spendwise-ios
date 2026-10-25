import AppIntents
import Foundation

// Small intents behind the snippet buttons. Hidden from the Shortcuts gallery.

struct SetCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Category"
    static let isDiscoverable = false

    @Parameter(title: "Transaction ID") var transactionID: String
    @Parameter(title: "Category") var category: String

    init() {}

    init(transactionID: String, category: String) {
        self.transactionID = transactionID
        self.category = category
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: transactionID) {
            SpendService(context: SharedStore.container.mainContext).setCategory(transactionID: id, category: category)
        }
        return .result()
    }
}

struct MarkTransferIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark as Transfer"
    static let isDiscoverable = false

    @Parameter(title: "Transaction ID") var transactionID: String

    init() {}

    init(transactionID: String) {
        self.transactionID = transactionID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: transactionID) {
            SpendService(context: SharedStore.container.mainContext).markTransfer(transactionID: id)
        }
        return .result()
    }
}

struct ConfirmSettlementIntent: AppIntent {
    static let title: LocalizedStringResource = "Confirm Settlement"
    static let isDiscoverable = false

    @Parameter(title: "Transaction ID") var transactionID: String

    init() {}

    init(transactionID: String) {
        self.transactionID = transactionID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: transactionID) {
            SpendService(context: SharedStore.container.mainContext).confirmSettlement(transactionID: id)
        }
        return .result()
    }
}

struct DismissReviewIntent: AppIntent {
    static let title: LocalizedStringResource = "Keep as Spending"
    static let isDiscoverable = false

    @Parameter(title: "Transaction ID") var transactionID: String

    init() {}

    init(transactionID: String) {
        self.transactionID = transactionID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: transactionID) {
            SpendService(context: SharedStore.container.mainContext).dismissReview(transactionID: id)
        }
        return .result()
    }
}

/// Opens the app on the split sheet; picking friends needs the full UI.
struct OpenSplitIntent: AppIntent {
    static let title: LocalizedStringResource = "Split Transaction"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Transaction ID") var transactionID: String

    init() {}

    init(transactionID: String) {
        self.transactionID = transactionID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: transactionID) {
            AppRouter.shared.sheet = .split(id)
        }
        return .result()
    }
}
