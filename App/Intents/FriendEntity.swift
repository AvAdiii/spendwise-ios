import AppIntents
import Foundation
import SwiftData

struct FriendEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Friend"
    static let defaultQuery = FriendQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(model: FriendModel) {
        id = model.id
        name = model.name
    }
}

struct FriendQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [FriendEntity] {
        try all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [FriendEntity] {
        try all().filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [FriendEntity] {
        try all()
    }

    @MainActor
    private func all() throws -> [FriendEntity] {
        let descriptor = FetchDescriptor<FriendModel>(sortBy: [SortDescriptor(\.name)])
        return try SharedStore.container.mainContext.fetch(descriptor).map(FriendEntity.init(model:))
    }
}
