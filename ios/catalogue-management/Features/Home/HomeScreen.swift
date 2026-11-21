import SwiftUI

struct HomeScreen: View {
    let container: AppContainer
    @State private var viewModel: HomeViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: HomeViewModel(repository: container.productRepository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    CatalogueLoadStateView(
                        state: viewModel.state,
                        emptyTitle: "Catalogue is empty",
                        emptyMessage: "Products and categories will appear here when available.",
                        retry: { Task { await viewModel.load() } }
                    ) { content in
                        VStack(alignment: .leading, spacing: 26) {
                            if !content.categories.isEmpty {
                                VStack(alignment: .leading, spacing: 13) {
                                    SectionHeading(title: "Shop by category", subtitle: "Find something you’re looking for")
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 9) {
                                            ForEach(content.categories) { category in
                                                CategoryChip(category: category, container: container)
                                            }
                                        }
                                        .padding(.vertical, 1)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeading(title: "Featured", subtitle: "Top-rated picks from our catalogue")
                                if content.featuredProducts.isEmpty {
                                    ContentUnavailableView("No featured products", systemImage: "shippingbox")
                                        .frame(maxWidth: .infinity, minHeight: 180)
                                } else {
                                    ProductGrid(products: Array(content.featuredProducts.prefix(5)), container: container)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Discover")
            .task {
                await viewModel.load()
            }
        }
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
