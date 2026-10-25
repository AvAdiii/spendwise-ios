import Foundation
import Observation

enum AppTab: String, Hashable {
    case today, activity, friends, plan, settings
}

enum AppSheet: Identifiable, Hashable {
    case quickLog(QuickLogMode?)
    case split(UUID)
    case checkpoint

    var id: String {
        switch self {
        case .quickLog(let mode): "quickLog-\(mode?.rawValue ?? "any")"
        case .split(let id): "split-\(id)"
        case .checkpoint: "checkpoint"
        }
    }
}

/// App-wide navigation state. A singleton because App Intents and widget deep links set it from outside SwiftUI.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var tab: AppTab = .today
    var sheet: AppSheet?

    /// spendwise://quicklog[/cash|friendPaid|paidForGroup], spendwise://split/<uuid>, spendwise://tab/<name>
    func handle(url: URL) {
        guard url.scheme == "spendwise" else { return }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host() {
        case "quicklog":
            sheet = .quickLog(parts.first.flatMap(QuickLogMode.init(rawValue:)))
        case "split":
            if let id = parts.first.flatMap(UUID.init(uuidString:)) { sheet = .split(id) }
        case "tab":
            if let t = parts.first.flatMap(AppTab.init(rawValue:)) { tab = t }
        default:
            break
        }
    }
}
