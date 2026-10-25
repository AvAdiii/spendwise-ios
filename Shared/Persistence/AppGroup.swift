import Foundation

/// Resolves the shared App Group. SideStore/AltStore re-sign with a rewritten group ID and
/// publish it under `ALTAppGroups` in Info.plist, so that list is tried before the default.
enum AppGroup {
    static let defaultIdentifier = "group.com.avaditya.spendwise"

    static let identifier: String = candidates.first { id in
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    } ?? defaultIdentifier

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    private static var candidates: [String] {
        var bundles = [Bundle.main]
        // Inside the widget extension, also read the containing app's Info.plist.
        if Bundle.main.bundleURL.pathExtension == "appex" {
            let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let app = Bundle(url: appURL) { bundles.append(app) }
        }
        let injected = bundles.flatMap { $0.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? [] }
        return injected + [defaultIdentifier]
    }
}
