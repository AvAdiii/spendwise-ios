import SpendCore
import SwiftData
import SwiftUI

struct TagEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var tag = "exam"
    @State private var from = IST.startOfDay(.now)
    @State private var to = IST.startOfDay(.now)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag", text: $tag)
                        .textInputAutocapitalization(.never)
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(EventEditor.tags, id: \.self) { t in
                                Button(t.capitalized) { tag = t }
                                    .buttonStyle(.bordered)
                                    .tint(tag == t ? .accentColor : .secondary)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                Section {
                    DatePicker("From", selection: $from, displayedComponents: .date)
                    DatePicker("To", selection: $to, in: from..., displayedComponents: .date)
                } footer: {
                    Text("For example, tag midsem week as \"exam\" or Felicity as \"fest\".")
                }
            }
            .navigationTitle("Tag Days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(tag.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        var day = IST.startOfDay(from)
        let last = IST.startOfDay(max(from, to))
        while day <= last {
            context.insert(TagModel(day: day, tag: tag, source: .manual))
            day = IST.addDays(1, to: day)
        }
        SpendService(context: context).commit()
        dismiss()
    }
}
