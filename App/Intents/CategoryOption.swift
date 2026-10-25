import AppIntents
import SpendCore

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

    static let caseDisplayRepresentations: [CategoryOption: DisplayRepresentation] = Dictionary(
        uniqueKeysWithValues: allCases.map { option in
            (option, DisplayRepresentation(title: "\(option.rawValue)", image: .init(systemName: Categories.symbol(for: option.rawValue))))
        }
    )
}
