import Foundation

/// Small preferences stored in the shared App Group defaults so the widget and intents see them.
enum AppSettings {
    static var defaults: UserDefaults { UserDefaults(suiteName: AppGroup.identifier) ?? .standard }

    private enum Key {
        static let nextTopUp = "nextTopUp"
        static let lastTopUp = "lastTopUp"
        static let userName = "userName"
        static let userVPA = "userVPA"
        static let calendarSync = "calendarSync"
        static let onboarded = "onboarded"
        static let alertMemory = "alertMemory"
        static let anomalyCheckedThrough = "anomalyCheckedThrough"
    }

    static var nextTopUp: Date? {
        get { defaults.object(forKey: Key.nextTopUp) as? Date }
        set { defaults.set(newValue, forKey: Key.nextTopUp) }
    }

    static var lastTopUp: Date? {
        get { defaults.object(forKey: Key.lastTopUp) as? Date }
        set { defaults.set(newValue, forKey: Key.lastTopUp) }
    }

    static var userName: String {
        get { defaults.string(forKey: Key.userName) ?? "" }
        set { defaults.set(newValue, forKey: Key.userName) }
    }

    static var userVPA: String {
        get { defaults.string(forKey: Key.userVPA) ?? "" }
        set { defaults.set(newValue, forKey: Key.userVPA) }
    }

    static var calendarSync: Bool {
        get { defaults.bool(forKey: Key.calendarSync) }
        set { defaults.set(newValue, forKey: Key.calendarSync) }
    }

    static var onboarded: Bool {
        get { defaults.bool(forKey: Key.onboarded) }
        set { defaults.set(newValue, forKey: Key.onboarded) }
    }

    static var anomalyCheckedThrough: Date? {
        get { defaults.object(forKey: Key.anomalyCheckedThrough) as? Date }
        set { defaults.set(newValue, forKey: Key.anomalyCheckedThrough) }
    }

    /// Remembers which alerts already fired (e.g. "pace-<period>" → band) so each fires once.
    static func alertValue(_ key: String) -> Int? {
        (defaults.dictionary(forKey: Key.alertMemory) as? [String: Int])?[key]
    }

    static func setAlertValue(_ value: Int, for key: String) {
        var memory = defaults.dictionary(forKey: Key.alertMemory) as? [String: Int] ?? [:]
        memory[key] = value
        defaults.set(memory, forKey: Key.alertMemory)
    }
}
