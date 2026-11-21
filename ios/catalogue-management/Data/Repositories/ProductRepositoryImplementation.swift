import Foundation

public struct ProductRepositoryImplementation: ProductRepository {
    private let apiClient: any APIClient

    public init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    public func featuredProducts() async throws -> [Product] {
        let response: DataEnvelope<[ProductWireDTO]> = try await apiClient.get(
            ["api", "v1", "products", "featured"],
            queryItems: [],
            as: DataEnvelope<[ProductWireDTO]>.self
        )
        return try response.data.map { try $0.domainModel }
    }

    public func categories() async throws -> [Category] {
        let response: DataEnvelope<[String]> = try await apiClient.get(
            ["api", "v1", "categories"],
            queryItems: [],
            as: DataEnvelope<[String]>.self
        )
        return response.data.map(Category.init(name:))
    }

    public func products(in category: Category) async throws -> CategoryProducts {
        let response: DataEnvelope<CategoryProductsWireDTO> = try await apiClient.get(
            ["api", "v1", "categories", category.name, "products"],
            queryItems: [],
            as: DataEnvelope<CategoryProductsWireDTO>.self
        )
        return try response.data.domainModel
    }

    public func searchProducts(query: String) async throws -> [Product] {
        let response: SearchProductsWireDTO = try await apiClient.get(
            ["api", "v1", "products", "search"],
            queryItems: [APIQueryItem(name: "q", value: query)],
            as: SearchProductsWireDTO.self
        )
        return try response.data.map { try $0.domainModel }
    }

    public func product(id: String) async throws -> Product {
        let response: DataEnvelope<ProductWireDTO> = try await apiClient.get(
            ["api", "v1", "products", id],
            queryItems: [],
            as: DataEnvelope<ProductWireDTO>.self
        )
        return try response.data.domainModel
    }
}

private struct DataEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}

private struct SearchProductsWireDTO: Decodable, Sendable {
    let data: [ProductWireDTO]
}

private struct CategoryProductsWireDTO: Decodable, Sendable {
    let category: String
    let featured: [ProductWireDTO]
    let remaining: [ProductWireDTO]

    var domainModel: CategoryProducts {
        get throws {
            CategoryProducts(
                category: Category(name: category),
                featured: try featured.map { try $0.domainModel },
                remaining: try remaining.map { try $0.domainModel }
            )
        }
    }
}

private struct ProductWireDTO: Decodable, Sendable {
    let id: String
    let title: String
    let description: String
    let category: String
    let imageUrl: String
    let price: Decimal
    let rating: ProductRatingWireDTO

    var domainModel: Product {
        get throws {
            guard let imageURL = URL(string: imageUrl), imageURL.scheme == "https" || imageURL.scheme == "http" else {
                throw APIError.decoding
            }
            return Product(
                id: id,
                title: title,
                description: description,
                category: Category(name: category),
                imageURL: imageURL,
                price: price,
                rating: ProductRating(rate: rating.rate, count: rating.count)
            )
        }
    }
}

private struct ProductRatingWireDTO: Decodable, Sendable {
    let rate: Double
    let count: Int
}
