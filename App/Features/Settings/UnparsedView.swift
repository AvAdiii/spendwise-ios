import SwiftData
import SwiftUI

struct UnparsedView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UnparsedSMSModel.receivedAt, order: .reverse) private var messages: [UnparsedSMSModel]
    @State private var retriedCount: Int?

    var body: some View {
        List {
            ForEach(messages) { m in
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.text).font(.callout).textSelection(.enabled)
                    Text(m.receivedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(messages[i]) }
                try? context.save()
            }
            if let retriedCount {
                Text("^[\(retriedCount) message](inflect: true) logged.").foregroundStyle(.secondary)
            }
        }
        .overlay {
            if messages.isEmpty {
                ContentUnavailableView("All SMS understood", systemImage: "checkmark.bubble",
                                       description: Text("Messages the parser can't read show up here instead of being dropped."))
            }
        }
        .navigationTitle("Unparsed")
        .toolbar {
            if !messages.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Retry", systemImage: "arrow.clockwise", action: retry)
                }
            }
        }
    }

    /// Re-runs the parser, e.g. after an update that learned a new SMS format.
    private func retry() {
        let service = SpendService(context: context)
        var fixed = 0
        for m in messages {
            let text = m.text, date = m.receivedAt
            context.delete(m)
            if service.ingestSMS(text, receivedAt: date) != .unparsed { fixed += 1 }
        }
        retriedCount = fixed
        try? context.save()
    }
}
