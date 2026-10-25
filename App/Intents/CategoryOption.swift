import AppIntents

/// Default categories as a Shortcuts menu.
enum CategoryOption: String, AppEnum, CaseIterable {
    case food = "Food"
    case groceries = "Groceries"
    case transport = "Transport"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case bills = "Bills & Recharge"
    case travel = "Travel"
    case health = "Health"
    case education = "Education"
    case personal = "Personal"
    case other = "Other"

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static let caseDisplayRepresentations: [CategoryOption: DisplayRepresentation] = [
        .food: DisplayRepresentation(title: "Food", image: .init(systemName: "fork.knife")),
        .groceries: DisplayRepresentation(title: "Groceries", image: .init(systemName: "basket")),
        .transport: DisplayRepresentation(title: "Transport", image: .init(systemName: "car")),
        .shopping: DisplayRepresentation(title: "Shopping", image: .init(systemName: "bag")),
        .entertainment: DisplayRepresentation(title: "Entertainment", image: .init(systemName: "popcorn")),
        .bills: DisplayRepresentation(title: "Bills & Recharge", image: .init(systemName: "bolt")),
        .travel: DisplayRepresentation(title: "Travel", image: .init(systemName: "tram")),
        .health: DisplayRepresentation(title: "Health", image: .init(systemName: "cross.case")),
        .education: DisplayRepresentation(title: "Education", image: .init(systemName: "book")),
        .personal: DisplayRepresentation(title: "Personal", image: .init(systemName: "person")),
        .other: DisplayRepresentation(title: "Other", image: .init(systemName: "tag")),
    ]
}
