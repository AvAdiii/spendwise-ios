import SwiftData
import SwiftUI

/// Manual fallback and parser test: paste a bank SMS and log it.
struct PasteSMSView: View {
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var result: String?

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 140)
                    .font(.callout)
                PasteButton(payloadType: String.self) { strings in
                    text = strings.first ?? ""
                }
            } footer: {
                Text("Paste an SBI debit or credit SMS. It's logged exactly as the automation would.")
            }
            Section {
                Button("Log it", systemImage: "square.and.arrow.down", action: log)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let result {
                    Text(result).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Paste an SMS")
    }

    private func log() {
        switch SpendService(context: context).ingestSMS(text) {
        case .recorded(_, let suggestion):
            result = suggestion == .pickCategory ? "Logged. Pick a category on the Today tab." : "Logged."
            text = ""
        case .duplicate:
            result = "Already logged (same reference number)."
        case .unparsed:
            result = "Couldn't read that. It's saved under Unparsed messages."
        }
    }
}
