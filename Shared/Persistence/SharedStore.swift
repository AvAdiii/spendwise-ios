import Foundation
import SwiftData

enum SharedStore {
    static let schema = Schema([
        TxModel.self, FriendModel.self, IOUModel.self, FixedCostModel.self, EventModel.self,
        TagModel.self, RuleModel.self, CheckpointModel.self, UnparsedSMSModel.self,
    ])

    /// Launch argument used by CI screenshots and previews: in-memory store seeded with demo data.
    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static let container: ModelContainer = makeContainer(inMemory: isDemo)

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let url = AppGroup.containerURL?.appending(path: "Spendwise.store") {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            // No App Group entitlement (e.g. unsigned build): app-private store, widget shows a placeholder.
            configuration = ModelConfiguration(schema: schema)
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not open the Spendwise store: \(error)")
        }
    }
}
