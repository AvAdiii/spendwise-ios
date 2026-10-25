import SpendCore
import SwiftUI

enum Theme {
    static let heroFontSize = 60.0
    static let iconSize = 36.0

    static func color(for category: String?) -> Color {
        switch category {
        case "Food": .orange
        case "Groceries": .green
        case "Transport": .blue
        case "Shopping": .pink
        case "Entertainment": .purple
        case "Bills & Recharge": .yellow
        case "Travel": .teal
        case "Health": .red
        case "Education": .indigo
        case "Personal": .mint
        case nil: .gray
        default: .brown
        }
    }

    /// Green while comfortably within budget, orange when under a quarter of the allowance remains, red when over.
    static func color(left: Money, allowance: Money) -> Color {
        if left < .zero { return .red }
        if allowance.isPositive, left.paise * 4 < allowance.paise { return .orange }
        return .green
    }
}
