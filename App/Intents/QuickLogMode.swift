import AppIntents

enum QuickLogMode: String, AppEnum, CaseIterable, Identifiable {
    case cash
    case friendPaid
    case paidForGroup

    var id: String { rawValue }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Log Type"

    static let caseDisplayRepresentations: [QuickLogMode: DisplayRepresentation] = [
        .cash: DisplayRepresentation(title: "Cash spend", image: .init(systemName: "banknote")),
        .friendPaid: DisplayRepresentation(title: "A friend paid for me", image: .init(systemName: "person.badge.clock")),
        .paidForGroup: DisplayRepresentation(title: "I paid for the group", image: .init(systemName: "person.3")),
    ]

    var title: String {
        switch self {
        case .cash: "Cash"
        case .friendPaid: "Friend paid"
        case .paidForGroup: "I paid for group"
        }
    }
}
