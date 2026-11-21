import Foundation
import XCTest
@testable import catalogue_management

final class APIClientTests: XCTestCase {
    func testGetDecodesSuccessfulResponseAndBuildsVersionedURL() async throws {
        let transport = MockHTTPTransport(response: .init(
            data: Data(#"{"data":["electronics"]}"#.utf8),
            statusCode: 200
        ))
        let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "https://catalogue.example")), transport: transport)

        let response: DataEnvelope<[String]> = try await client.get(
            ["api", "v1", "categories"],
            as: DataEnvelope<[String]>.self
        )
        let sentRequests = await transport.requests()
        let request = try XCTUnwrap(sentRequests.first)

        XCTAssertEqual(response.data, ["electronics"])
        XCTAssertEqual(request.url?.path, "/api/v1/categories")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    func testHTTPErrorDecodesOnlySafeErrorCode() async throws {
        let transport = MockHTTPTransport(response: .init(
            data: Data(#"{"error":{"code":"PRODUCT_NOT_FOUND","message":"private details","details":[]}}"#.utf8),
            statusCode: 404
        ))
        let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "https://catalogue.example")), transport: transport)

        do {
            let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
            XCTFail("Expected an HTTP status error")
        } catch let error as APIError {
            XCTAssertEqual(error, .httpStatus(statusCode: 404, code: "PRODUCT_NOT_FOUND"))
            XCTAssertFalse(error.localizedDescription.contains("private details"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeoutMapsToTypedTimeoutError() async throws {
        let transport = MockHTTPTransport(failure: .timedOut)
        let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "https://catalogue.example")), transport: transport)

        do {
            let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
            XCTFail("Expected a timeout")
        } catch let error as APIError {
            XCTAssertEqual(error, .timedOut)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedSuccessBodyMapsToDecodingError() async throws {
        let transport = MockHTTPTransport(response: .init(data: Data("{}".utf8), statusCode: 200))
        let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "https://catalogue.example")), transport: transport)

        do {
            let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
            XCTFail("Expected a decoding error")
        } catch let error as APIError {
            XCTAssertEqual(error, .decoding)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHTTPRemoteBaseIsRejected() async throws {
        let transport = MockHTTPTransport(response: .init(data: Data(#"{"data":[]}"#.utf8), statusCode: 200))
        let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "http://public.example")), transport: transport)

        do {
            let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
            XCTFail("Expected an invalid URL error")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHTTPIsAllowedForExplicitLoopbackHosts() async throws {
        for address in ["http://localhost:3000", "http://127.0.0.1:3000", "http://[::1]:3000"] {
            let transport = MockHTTPTransport(response: .init(data: Data(#"{"data":[]}"#.utf8), statusCode: 200))
            let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: address)), transport: transport)
            let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
        }
    }

    func testUnsupportedSchemesAreRejectedEvenForLoopbackHosts() async {
        for address in ["ftp://localhost/catalogue", "file://localhost/catalogue", "catalogue://127.0.0.1"] {
            let transport = MockHTTPTransport(response: .init(data: Data(#"{"data":[]}"#.utf8), statusCode: 200))
            guard let baseURL = URL(string: address) else {
                XCTFail("Expected a valid test URL: \(address)")
                continue
            }
            let client = URLSessionAPIClient(baseURL: baseURL, transport: transport)

            do {
                let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
                XCTFail("Expected unsupported scheme to be rejected: \(address)")
            } catch let error as APIError {
                XCTAssertEqual(error, .invalidURL)
            } catch {
                XCTFail("Unexpected error for \(address): \(error)")
            }

            let sentRequests = await transport.requests()
            XCTAssertTrue(sentRequests.isEmpty)
        }
    }

    func testGenericTransportFailureMapsToSafeError() async throws {
        let transport = MockHTTPTransport(failure: .cannotConnectToHost)
        let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "https://catalogue.example")), transport: transport)

        do {
            let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
            XCTFail("Expected a transport error")
        } catch let error as APIError {
            XCTAssertEqual(error, .transport)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancelledURLSessionTransportErrorIsPreservedAsCancellation() async throws {
        let transport = MockHTTPTransport(failure: .cancelled)
        let client = URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: "https://catalogue.example")), transport: transport)

        do {
            let _: DataEnvelope<[String]> = try await client.get(["api", "v1", "categories"], as: DataEnvelope<[String]>.self)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Cancellation must not be converted into a user-facing transport failure.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct DataEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}

private actor MockHTTPTransport: HTTPTransport {
    private let response: HTTPTransportResponse?
    private let failure: URLError.Code?
    private var sentRequests: [URLRequest] = []

    init(response: HTTPTransportResponse) {
        self.response = response
        failure = nil
    }

    init(failure: URLError.Code) {
        response = nil
        self.failure = failure
    }

    func send(_ request: URLRequest) async throws -> HTTPTransportResponse {
        sentRequests.append(request)
        if let failure { throw URLError(failure) }
        guard let response else { throw URLError(.badServerResponse) }
        return response
    }

    func requests() -> [URLRequest] { sentRequests }
}
