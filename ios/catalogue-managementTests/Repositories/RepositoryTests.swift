import Foundation
import XCTest
@testable import catalogue_management

final class RepositoryTests: XCTestCase {
    func testProductRepositoryMapsProductDTOAndUsesFeaturedEndpoint() async throws {
        let transport = StubTransport(json: #"{"data":[{"id":"1","title":"Boot","description":"Leather boot","category":"women's clothing","imageUrl":"https://img.example/boot.jpg","price":42.5,"rating":{"rate":4.7,"count":8}}]}"#)
        let repository = ProductRepositoryImplementation(apiClient: try apiClient(transport))

        let products = try await repository.featuredProducts()
        let sentRequests = await transport.requests()
        let request = try XCTUnwrap(sentRequests.first)

        XCTAssertEqual(products.first?.id, "1")
        XCTAssertEqual(products.first?.category, Category(name: "women's clothing"))
        XCTAssertEqual(products.first?.imageURL.absoluteString, "https://img.example/boot.jpg")
        XCTAssertEqual(products.first?.rating, ProductRating(rate: 4.7, count: 8))
        XCTAssertEqual(request.url?.path, "/api/v1/products/featured")
    }

    func testProductRepositoryLoadsCategoriesAsDomainValues() async throws {
        let transport = StubTransport(json: #"{"data":["electronics","jewelery"]}"#)
        let repository = ProductRepositoryImplementation(apiClient: try apiClient(transport))

        let categories = try await repository.categories()
        XCTAssertEqual(categories, [Category(name: "electronics"), Category(name: "jewelery")])
    }

    func testCategoryRepositoryEncodesCategoryAsSinglePathSegment() async throws {
        let transport = StubTransport(json: #"{"data":{"category":"women's clothing","featured":[],"remaining":[]}}"#)
        let repository = ProductRepositoryImplementation(apiClient: try apiClient(transport))

        let result = try await repository.products(in: Category(name: "women's clothing"))
        let sentRequests = await transport.requests()
        let request = try XCTUnwrap(sentRequests.first)

        XCTAssertEqual(result.category.name, "women's clothing")
        XCTAssertEqual(request.url?.path, "/api/v1/categories/women's clothing/products")
        let percentEncodedPath = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.percentEncodedPath
        XCTAssertTrue(percentEncodedPath?.contains("women%27s%20clothing") == true)
    }

    func testSearchRepositoryPassesQueryAndDecodesResults() async throws {
        let transport = StubTransport(json: #"{"data":[],"meta":{"query":"bag","count":0}}"#)
        let repository = ProductRepositoryImplementation(apiClient: try apiClient(transport))

        let products = try await repository.searchProducts(query: "bag")
        XCTAssertTrue(products.isEmpty)
        let sentRequests = await transport.requests()
        let request = try XCTUnwrap(sentRequests.first)

        XCTAssertEqual(request.url?.path, "/api/v1/products/search")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "bag")
    }

    func testProductRepositoryLoadsDetailByStringID() async throws {
        let transport = StubTransport(json: #"{"data":{"id":"25","title":"Detail","description":"Description","category":"electronics","imageUrl":"https://img.example/detail.jpg","price":15,"rating":{"rate":4,"count":1}}}"#)
        let repository = ProductRepositoryImplementation(apiClient: try apiClient(transport))

        let product = try await repository.product(id: "25")
        XCTAssertEqual(product.title, "Detail")
        let sentRequests = await transport.requests()
        let request = try XCTUnwrap(sentRequests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/products/25")
    }

    func testEnquiryRepositoryEncodesNumericProductIDAndOmitsAbsentPhone() async throws {
        let transport = StubTransport(json: #"{"data":{"status":"sent"}}"#)
        let repository = EnquiryRepositoryImplementation(apiClient: try apiClient(transport))
        let request = EnquiryRequest(
            productId: 7,
            name: "John Doe",
            email: "john@example.com",
            message: "Please contact me."
        )

        let response = try await repository.submit(request)
        XCTAssertEqual(response, EnquiryResponse(status: "sent"))
        let sentRequests = await transport.requests()
        let captured = try XCTUnwrap(sentRequests.first)
        let body = try XCTUnwrap(captured.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(object["productId"] as? Int, 7)
        XCTAssertNil(object["phone"])
        XCTAssertEqual(captured.url?.path, "/api/v1/enquiries")
    }

    func testEnquiryRequestSafelyConvertsCanonicalNumericProductIDs() throws {
        let request = try EnquiryRequest(
            product: product(withID: "42"),
            name: "John Doe",
            email: "john@example.com",
            message: "Please contact me."
        )

        XCTAssertEqual(request.productId, 42)

        let maximumSafeRequest = try EnquiryRequest(
            product: product(withID: "9007199254740991"),
            name: "John Doe",
            email: "john@example.com",
            message: "Please contact me."
        )
        XCTAssertEqual(maximumSafeRequest.productId, EnquiryRequest.maximumSafeProductID)
    }

    func testEnquiryRequestRejectsInvalidZeroNegativeAndUnsafeProductIDs() {
        let invalidIDs = ["abc", "", "0", "-1", "9007199254740992"]
        for id in invalidIDs {
            XCTAssertThrowsError(try EnquiryRequest(
                product: product(withID: id),
                name: "John Doe",
                email: "john@example.com",
                message: "Please contact me."
            )) { error in
                XCTAssertEqual(error as? EnquiryRequestCreationError, .invalidProductID)
                XCTAssertEqual(error.localizedDescription, "This product cannot be used for an enquiry.")
            }
        }
    }

    private func apiClient(_ transport: StubTransport) throws -> URLSessionAPIClient {
        URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "https://catalogue.example")), transport: transport)
    }

    private func product(withID id: String) -> Product {
        Product(
            id: id,
            title: "Product",
            description: "Description",
            category: Category(name: "electronics"),
            imageURL: URL(fileURLWithPath: "/image.jpg"),
            price: 1,
            rating: ProductRating(rate: 4, count: 1)
        )
    }
}

private actor StubTransport: HTTPTransport {
    private let response: HTTPTransportResponse
    private var sentRequests: [URLRequest] = []

    init(json: String, statusCode: Int = 200) {
        response = HTTPTransportResponse(data: Data(json.utf8), statusCode: statusCode)
    }

    func send(_ request: URLRequest) async throws -> HTTPTransportResponse {
        sentRequests.append(request)
        return response
    }

    func requests() -> [URLRequest] { sentRequests }
}
