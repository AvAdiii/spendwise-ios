import SpendCore
import SwiftUI

struct CategoryGrid: View {
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Categories.defaults, id: \.self) { name in
                Button {
                    selection = name
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: Categories.symbol(for: name))
                            .font(.title3)
                        Text(name)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(selection == name ? .white : Theme.color(for: name))
                    .background(selection == name ? Theme.color(for: name) : Theme.color(for: name).opacity(0.12),
                                in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(selection == name ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
