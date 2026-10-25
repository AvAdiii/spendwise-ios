import SpendCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \CheckpointModel.date, order: .reverse) private var checkpoints: [CheckpointModel]
    @Query private var unparsed: [UnparsedSMSModel]

    @State private var userName = AppSettings.userName
    @State private var userVPA = AppSettings.userVPA
    @State private var calendarSync = AppSettings.calendarSync
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Balance") {
                    if let last = checkpoints.first {
                        LabeledContent("Last confirmed", value: last.date.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("Update balance", systemImage: "building.columns") { router.sheet = .checkpoint }
                }

                Section {
                    TextField("Your name", text: $userName)
                        .textContentType(.name)
                    TextField("Your UPI ID", text: $userVPA)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("You")
                } footer: {
                    Text("Used in the payment request links you send friends.")
                }

                Section("Capture") {
                    NavigationLink { ShortcutsGuideView() } label: {
                        Label("Set up SMS automation", systemImage: "wand.and.stars")
                    }
                    NavigationLink { PasteSMSView() } label: {
                        Label("Paste an SMS", systemImage: "doc.on.clipboard")
                    }
                    NavigationLink { UnparsedView() } label: {
                        LabeledContent {
                            Text("\(unparsed.count)")
                        } label: {
                            Label("Unparsed messages", systemImage: "exclamationmark.bubble")
                        }
                    }
                }

                Section {
                    Toggle(isOn: $calendarSync) {
                        Label("Tag days from Calendar", systemImage: "calendar")
                    }
                    Button("Allow notifications", systemImage: "bell.badge") {
                        Task { _ = await AlertScheduler.shared.requestAuthorization() }
                    }
                    NavigationLink { RulesView() } label: {
                        Label("Learned categories", systemImage: "tag")
                    }
                } header: {
                    Text("Forecast & alerts")
                } footer: {
                    Text("Calendar events with words like party, trip, exam or fest tag those days. Alerts are about your pace, not fixed limits.")
                }

                Section {
                    Button("Export backup", systemImage: "square.and.arrow.up", action: export)
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share \(exportURL.lastPathComponent)", systemImage: "doc")
                        }
                    }
                    Button("Restore from backup", systemImage: "square.and.arrow.down") { showImporter = true }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Sideloaded apps have no iCloud backup. Export now and then to Files.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    LabeledContent("App Group", value: AppGroup.containerURL == nil ? "Unavailable" : "Shared")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: userName) { _, v in AppSettings.userName = v }
            .onChange(of: userVPA) { _, v in AppSettings.userVPA = v.trimmingCharacters(in: .whitespaces) }
            .onChange(of: calendarSync) { _, on in
                AppSettings.calendarSync = on
                guard on else { return }
                Task {
                    if await CalendarTagger.requestAccess() {
                        CalendarTagger.sync(context: context)
                    } else {
                        calendarSync = false
                        errorMessage = "Calendar access was denied. Enable it in the Settings app."
                    }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        try BackupService.restore(from: url, context: context)
                        userName = AppSettings.userName
                        userVPA = AppSettings.userVPA
                    } catch {
                        errorMessage = "Couldn't restore: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding { errorMessage != nil } set: { if !$0 { errorMessage = nil } }
    }

    private func export() {
        do {
            exportURL = try BackupService.export(context: context)
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}
