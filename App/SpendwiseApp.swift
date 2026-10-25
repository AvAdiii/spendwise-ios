import SwiftData
import SwiftUI

@main
struct SpendwiseApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var delegate
    @State private var router = AppRouter.shared

    init() {
        if SharedStore.isDemo {
            DemoData.seed(SharedStore.container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { router.handle(url: $0) }
        }
        .modelContainer(SharedStore.container)
    }
}
