import SwiftUI

struct ShortcutsGuideView: View {
    @Environment(\.openURL) private var openURL

    private let steps: [(String, String)] = [
        ("Open Shortcuts › Automation", "Tap + and choose Message."),
        ("Message contains \"debited\"", "Leave Sender empty. Choose Run Immediately and turn off Notify When Run if you like."),
        ("Add the Log Bank SMS action", "Search Spendwise › Log Bank SMS. Tap Message and pick the Shortcut Input › Message Content."),
        ("Repeat for \"credited\"", "Make a second automation so refunds and friends paying you back are caught."),
        ("Optional: ATM", "A third automation for \"withdrawn\" moves ATM cash into your cash wallet."),
        ("Action Button", "Settings › Action Button › Shortcut › Spendwise › Quick Log."),
    ]

    var body: some View {
        List {
            Section {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                            .background(.tint.opacity(0.15), in: .circle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(steps[i].0).font(.headline)
                            Text(steps[i].1).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("iOS may file bank alerts under Messages › Transactions. Send yourself a test by pasting a real SMS under Settings › Paste an SMS, then check that the automation fires on the next real payment.")
            }

            Section {
                Button("Open Shortcuts", systemImage: "arrow.up.forward.app") {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                }
            }
        }
        .navigationTitle("SMS Automation")
    }
}
