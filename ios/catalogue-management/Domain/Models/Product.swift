import Foundation

public struct Product: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let category: Category
    public let imageURL: URL
    public let price: Decimal
    public let rating: ProductRating

    public init(
        id: String,
        title: String,
        description: String,
        category: Category,
        imageURL: URL,
        price: Decimal,
        rating: ProductRating
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.imageURL = imageURL
        self.price = price
        self.rating = rating
    }
}
