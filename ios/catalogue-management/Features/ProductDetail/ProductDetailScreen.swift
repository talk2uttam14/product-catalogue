import SwiftUI

struct ProductDetailScreen: View {
    let container: AppContainer
    let productID: String
    @State private var viewModel: ProductDetailViewModel

    init(container: AppContainer, productID: String) {
        self.container = container
        self.productID = productID
        _viewModel = State(initialValue: ProductDetailViewModel(repository: container.productRepository))
    }

    var body: some View {
        ScrollView {
            CatalogueLoadStateView(
                state: viewModel.state,
                emptyTitle: "Product unavailable",
                emptyMessage: "This product is no longer available.",
                retry: { Task { await viewModel.load(productID: productID) } }
            ) { product in
                VStack(alignment: .leading, spacing: 22) {
                    AsyncImage(url: product.imageURL) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFit().padding(24)
                        case .empty:
                            ProgressView().accessibilityLabel("Loading product image")
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Product image unavailable")
                        @unknown default:
                            Image(systemName: "photo").foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(product.title)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Text(product.price.formatted(.currency(code: "USD")))
                                .font(.title3.weight(.semibold))
                            Label("\(product.rating.rate.formatted(.number.precision(.fractionLength(1)))) · \(product.rating.count) reviews", systemImage: "star.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }

                        Text(product.category.name.localizedCapitalized)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(.quaternary, in: Capsule())
                            .accessibilityLabel("Category: \(product.category.name)")
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("About this product")
                            .font(.headline)
                        Text(product.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NavigationLink {
                        EnquiryScreen(container: container, product: product)
                    } label: {
                        Label("Enquire Now", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint("Ask a question about this product")
                }
                .padding(18)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: productID) {
            await viewModel.load(productID: productID)
        }
    }
}
