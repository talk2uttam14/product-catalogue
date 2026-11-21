import Foundation
import Observation

public struct HomeContent: Equatable, Sendable {
    public let categories: [Category]
    public let featuredProducts: [Product]

    public init(categories: [Category], featuredProducts: [Product]) {
        self.categories = categories
        self.featuredProducts = featuredProducts
    }
}

@MainActor
@Observable
public final class HomeViewModel {
    public private(set) var state: LoadState<HomeContent> = .idle
    private let repository: any ProductRepository
    private var requestGeneration: UInt64 = 0

    public init(repository: any ProductRepository) {
        self.repository = repository
    }

    public func load() async {
        requestGeneration &+= 1
        let generation = requestGeneration
        state = .loading
        do {
            async let categories = repository.categories()
            async let featured = repository.featuredProducts()
            let content = try await HomeContent(categories: categories, featuredProducts: featured)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            state = content.categories.isEmpty && content.featuredProducts.isEmpty ? .empty : .loaded(content)
        } catch {
            guard generation == requestGeneration else { return }
            if isCancellationError(error) {
                state = .idle
                return
            }
            state = .failed(userFacingMessage(for: error))
        }
    }
}
