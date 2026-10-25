import SwiftData
import SwiftUI

/// Payee → category corrections the user made; each one is reused for future SMS.
struct RulesView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<RuleModel> { $0.exact == true }, sort: \RuleModel.keyword) private var rules: [RuleModel]

    var body: some View {
        List {
            ForEach(rules) { rule in
                LabeledContent(rule.keyword.uppercased(), value: rule.category)
            }
            .onDelete { offsets in
                for i in offsets { context.delete(rules[i]) }
                try? context.save()
            }
        }
        .overlay {
            if rules.isEmpty {
                ContentUnavailableView("Nothing learned yet", systemImage: "tag",
                                       description: Text("When you change a transaction's category, that payee is remembered here."))
            }
        }
        .navigationTitle("Learned Categories")
    }
}
