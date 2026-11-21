import Foundation
import Observation

@MainActor
@Observable
public final class SearchViewModel {
    public private(set) var state: LoadState<[Product]> = .idle
    private let repository: any ProductRepository
    private var requestGeneration: UInt64 = 0

    public init(repository: any ProductRepository) {
        self.repository = repository
    }

    public func search(query: String) async {
        requestGeneration &+= 1
        let generation = requestGeneration
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            state = .empty
            return
        }

        state = .loading
        do {
            let products = try await repository.searchProducts(query: normalizedQuery)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            state = products.isEmpty ? .empty : .loaded(products)
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
