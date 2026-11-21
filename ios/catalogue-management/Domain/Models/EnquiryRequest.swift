import Foundation

public struct EnquiryRequest: Equatable, Sendable {
    public static let maximumSafeProductID = 9_007_199_254_740_991

    public let productId: Int
    public let name: String
    public let email: String
    public let phone: String?
    public let message: String

    public init(productId: Int, name: String, email: String, phone: String? = nil, message: String) {
        self.productId = productId
        self.name = name
        self.email = email
        self.phone = phone
        self.message = message
    }

    public init(
        product: Product,
        name: String,
        email: String,
        phone: String? = nil,
        message: String
    ) throws {
        let id = product.id
        guard !id.isEmpty,
              id.utf8.allSatisfy({ (48...57).contains($0) }),
              let productId = Int(id),
              productId > 0,
              productId <= Self.maximumSafeProductID,
              String(productId) == id
        else {
            throw EnquiryRequestCreationError.invalidProductID
        }
        self.init(productId: productId, name: name, email: email, phone: phone, message: message)
    }
}

public enum EnquiryRequestCreationError: Error, Equatable, Sendable, LocalizedError {
    case invalidProductID

    public var errorDescription: String? {
        "This product cannot be used for an enquiry."
    }
}
