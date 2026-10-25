import AppIntents
import Foundation

/// Called by the Shortcuts "Message" automation with the SMS body.
struct LogBankSMSIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Bank SMS"
    static let description = IntentDescription("Reads an SBI UPI alert, logs the transaction and shows a quick editor.")

    @Parameter(title: "Message", inputOptions: String.IntentInputOptions(multiline: true))
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$message)")
    }

    init() {}

    init(message: String) {
        self.message = message
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetIntent {
        let service = SpendService(context: SharedStore.container.mainContext)
        let status: String
        var transactionID = ""
        switch service.ingestSMS(message) {
        case .recorded(let id, _):
            transactionID = id.uuidString
            status = "logged"
        case .duplicate:
            status = "duplicate"
        case .unparsed:
            status = "unparsed"
        }
        return .result(snippetIntent: TransactionSnippetIntent(transactionID: transactionID, status: status))
    }
}
