import SwiftUI

struct CategoryChip: View {
    let category: Category
    let container: AppContainer

    var body: some View {
        NavigationLink {
            CategoryScreen(container: container, category: category)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "square.grid.2x2")
                    .font(.caption.weight(.semibold))
                Text(category.name.localizedCapitalized)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.primary)
            .background(.quaternary.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Browse products in \(category.name)")
    }

}
