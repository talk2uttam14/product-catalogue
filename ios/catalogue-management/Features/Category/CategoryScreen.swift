import SwiftUI

struct CategoryScreen: View {
    let container: AppContainer
    let category: Category
    @State private var viewModel: CategoryViewModel

    init(container: AppContainer, category: Category) {
        self.container = container
        self.category = category
        _viewModel = State(initialValue: CategoryViewModel(repository: container.productRepository))
    }

    var body: some View {
        ScrollView {
            CatalogueLoadStateView(
                state: viewModel.state,
                emptyTitle: "No products in this category",
                emptyMessage: "Try another category to see more products.",
                retry: { Task { await viewModel.load(category: category) } }
            ) { content in
                VStack(alignment: .leading, spacing: 26) {
                    if !content.featured.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeading(title: "Top rated", subtitle: "The highest-rated products in this category")
                            ProductGrid(products: Array(content.featured.prefix(5)), container: container)
                        }
                    }

                    if !content.remaining.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeading(title: "More to explore", subtitle: "More from \(content.category.name.localizedCapitalized)")
                            ProductGrid(products: content.remaining, container: container)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(category.name.localizedCapitalized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: category.name) {
            await viewModel.load(category: category)
        }
    }
}
