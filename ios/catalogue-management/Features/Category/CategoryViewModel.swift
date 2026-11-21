import Foundation
import Observation

@MainActor
@Observable
public final class CategoryViewModel {
    public private(set) var state: LoadState<CategoryProducts> = .idle
    private let repository: any ProductRepository
    private var requestGeneration: UInt64 = 0

    public init(repository: any ProductRepository) {
        self.repository = repository
    }

    public func load(category: Category) async {
        requestGeneration &+= 1
        let generation = requestGeneration
        state = .loading
        do {
            let products = try await repository.products(in: category)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            state = products.featured.isEmpty && products.remaining.isEmpty ? .empty : .loaded(products)
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
