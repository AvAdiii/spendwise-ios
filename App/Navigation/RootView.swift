import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding = !AppSettings.onboarded && !SharedStore.isDemo

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Today", systemImage: "indianrupeesign.circle", value: AppTab.today) {
                TodayView()
            }
            Tab("Activity", systemImage: "list.bullet.rectangle", value: AppTab.activity) {
                ActivityView()
            }
            Tab("Friends", systemImage: "person.2", value: AppTab.friends) {
                FriendsView()
            }
            Tab("Plan", systemImage: "calendar", value: AppTab.plan) {
                PlanView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .quickLog(let mode):
                QuickLogSheet(initialMode: mode ?? .cash)
            case .split(let id):
                SplitSheetLoader(transactionID: id)
            case .checkpoint:
                CheckpointSheet()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .task {
            applyLaunchArguments()
            refresh()
        }
    }

    private func refresh() {
        if AppSettings.calendarSync { CalendarTagger.sync(context: context) }
        Task { await AlertScheduler.shared.evaluate(context: context) }
    }

    /// `-tab friends` lets CI capture a screenshot of each tab.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let tab = AppTab(rawValue: args[i + 1]) {
            router.tab = tab
        }
    }
}
