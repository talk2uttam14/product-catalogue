import Foundation

public struct HTTPTransportResponse: Sendable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPTransportResponse
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = URLSession(configuration: .default)) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> HTTPTransportResponse {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPTransportResponse(data: data, statusCode: response.statusCode)
    }
}
