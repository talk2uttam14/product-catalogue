import SwiftUI

struct ProductGrid: View {
    let products: [Product]
    let container: AppContainer

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(products) { product in
                NavigationLink {
                    ProductDetailScreen(container: container, productID: product.id)
                } label: {
                    ProductCard(product: product)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens product details")
            }
        }
    }
}
