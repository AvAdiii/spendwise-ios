import Foundation
import SpendCore
import WidgetKit

struct SpendEntry: TimelineEntry {
    var date: Date
    /// nil until the user has set a balance in the app.
    var leftToday: Money?
    var allowance: Money
    var daysLeft: Int
    var runOutText: String
    var isRunningOut: Bool
    var payable: Money
    var receivable: Money

    static let sample = SpendEntry(date: .now, leftToday: Money(rupees: 420), allowance: Money(rupees: 560), daysLeft: 9,
                                   runOutText: "Lasts until top-up on 3 Nov", isRunningOut: false,
                                   payable: Money(rupees: 239), receivable: Money(rupees: 620))

    static let empty = SpendEntry(date: .now, leftToday: nil, allowance: .zero, daysLeft: 0,
                                  runOutText: "Open Spendwise to set your balance", isRunningOut: false,
                                  payable: .zero, receivable: .zero)
}
