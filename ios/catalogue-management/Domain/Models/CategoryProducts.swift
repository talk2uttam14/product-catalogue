import Foundation

public struct CategoryProducts: Equatable, Sendable {
    public let category: Category
    public let featured: [Product]
    public let remaining: [Product]

    public init(category: Category, featured: [Product], remaining: [Product]) {
        self.category = category
        self.featured = featured
        self.remaining = remaining
    }
}
