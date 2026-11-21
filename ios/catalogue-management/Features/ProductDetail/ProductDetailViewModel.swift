import Foundation
import Observation

@MainActor
@Observable
public final class ProductDetailViewModel {
    public private(set) var state: LoadState<Product> = .idle
    private let repository: any ProductRepository
    private var requestGeneration: UInt64 = 0

    public init(repository: any ProductRepository) {
        self.repository = repository
    }

    public func load(productID: String) async {
        requestGeneration &+= 1
        let generation = requestGeneration
        state = .loading
        do {
            let product = try await repository.product(id: productID)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            state = .loaded(product)
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
