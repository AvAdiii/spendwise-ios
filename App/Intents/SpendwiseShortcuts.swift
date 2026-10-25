import AppIntents

struct SpendwiseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogIntent(),
            phrases: ["Quick log in \(.applicationName)", "Log a spend in \(.applicationName)"],
            shortTitle: "Quick Log",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: SafeToSpendIntent(),
            phrases: ["How much can I spend in \(.applicationName)", "\(.applicationName) safe to spend"],
            shortTitle: "Safe to Spend",
            systemImageName: "indianrupeesign.circle"
        )
        AppShortcut(
            intent: LogBankSMSIntent(),
            phrases: ["Log bank SMS in \(.applicationName)"],
            shortTitle: "Log Bank SMS",
            systemImageName: "message"
        )
    }
}
