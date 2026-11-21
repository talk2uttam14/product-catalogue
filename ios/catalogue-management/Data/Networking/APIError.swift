import Foundation

public enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case encoding
    case decoding
    case timedOut
    case transport
    case httpStatus(statusCode: Int, code: String?)
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The service address is invalid."
        case .encoding:
            "The request could not be prepared."
        case .decoding:
            "The service returned an unexpected response."
        case .timedOut:
            "The request timed out. Please try again."
        case .transport:
            "The service could not be reached. Please try again."
        case let .httpStatus(_, code) where code == "PRODUCT_NOT_FOUND":
            "This product could not be found."
        case let .httpStatus(_, code) where code == "CATEGORY_NOT_FOUND":
            "This category could not be found."
        case let .httpStatus(_, code) where code == "EMAIL_DELIVERY_FAILED":
            "The enquiry could not be sent. Please try again."
        case .httpStatus:
            "The service could not complete the request. Please try again."
        }
    }
}
