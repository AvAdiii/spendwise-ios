import SwiftUI

struct SetBalancePrompt: View {
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Set your balance", systemImage: "building.columns")
        } description: {
            Text("Enter your current bank balance and cash once. Spendwise keeps it up to date from your SMS.")
        } actions: {
            Button("Set balance", action: action)
                .buttonStyle(.borderedProminent)
        }
    }
}
