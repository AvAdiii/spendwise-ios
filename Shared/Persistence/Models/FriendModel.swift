import Foundation
import SpendCore
import SwiftData

@Model
final class FriendModel {
    var id: UUID = UUID()
    var name: String = ""
    /// Payee names as they appear in bank SMS, e.g. "PRIYA SHARMA".
    var aliases: [String] = []
    var vpa: String?
    var createdAt: Date = Date.now

    init(name: String, aliases: [String] = [], vpa: String? = nil) {
        self.name = name
        self.aliases = aliases
        self.vpa = vpa
    }

    var friend: Friend { Friend(id: id, name: name, aliases: aliases, vpa: vpa) }
}
