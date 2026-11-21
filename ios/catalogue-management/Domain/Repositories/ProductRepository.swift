import Foundation

public protocol ProductRepository: Sendable {
    func featuredProducts() async throws -> [Product]
    func categories() async throws -> [Category]
    func products(in category: Category) async throws -> CategoryProducts
    func searchProducts(query: String) async throws -> [Product]
    func product(id: String) async throws -> Product
}
