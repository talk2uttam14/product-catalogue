import SwiftUI

struct SearchScreen: View {
    let container: AppContainer
    @State private var viewModel: SearchViewModel
    @State private var query = ""
    @State private var requestedQuery = ""

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: SearchViewModel(repository: container.productRepository))
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                searchField
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                if normalizedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search the catalogue",
                        systemImage: "magnifyingglass",
                        description: Text("Search by product name, description, or category.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if requestedQuery != normalizedQuery {
                    ProgressView("Waiting to search…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("catalogue.searchDebouncing")
                } else {
                    CatalogueLoadStateView(
                        state: viewModel.state,
                        emptyTitle: "No matching products",
                        emptyMessage: "Try another title, description, or category.",
                        retry: { Task { await viewModel.search(query: normalizedQuery) } }
                    ) { products in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeading(title: "Results", subtitle: "\(products.count) products found")
                                ProductGrid(products: products, container: container)
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Search")
            .task(id: query) {
                let searchTerm = normalizedQuery
                guard !searchTerm.isEmpty else {
                    requestedQuery = ""
                    await viewModel.search(query: "")
                    return
                }

                do {
                    try await Task.sleep(for: .milliseconds(350))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                requestedQuery = searchTerm
                await viewModel.search(query: searchTerm)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Title, description or category", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("catalogue.searchField")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
