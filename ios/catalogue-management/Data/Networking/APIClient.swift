import Foundation

public struct APIQueryItem: Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public protocol APIClient: Sendable {
    func get<Response: Decodable & Sendable>(
        _ path: [String],
        queryItems: [APIQueryItem],
        as responseType: Response.Type
    ) async throws -> Response

    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: [String],
        body: Body,
        as responseType: Response.Type
    ) async throws -> Response
}

public struct URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let timeoutInterval: TimeInterval

    public init(
        baseURL: URL,
        transport: any HTTPTransport = URLSessionTransport(),
        timeoutInterval: TimeInterval = 15
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.timeoutInterval = timeoutInterval
    }

    public func get<Response: Decodable & Sendable>(
        _ path: [String],
        queryItems: [APIQueryItem] = [],
        as responseType: Response.Type
    ) async throws -> Response {
        let request = try makeRequest(path, method: "GET", queryItems: queryItems)
        return try await send(request, as: responseType)
    }

    public func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: [String],
        body: Body,
        as responseType: Response.Type
    ) async throws -> Response {
        var request = try makeRequest(path, method: "POST", queryItems: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try makeEncoder().encode(body)
        } catch {
            throw APIError.encoding
        }
        return try await send(request, as: responseType)
    }

    private func makeRequest(
        _ path: [String],
        method: String,
        queryItems: [APIQueryItem]
    ) throws -> URLRequest {
        let scheme = baseURL.scheme?.lowercased()
        let host = baseURL.host?.lowercased()
        let isLoopbackHost = host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
        let isAllowedScheme = scheme == "https" || (scheme == "http" && isLoopbackHost)

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              !path.isEmpty,
              isAllowedScheme
        else {
            throw APIError.invalidURL
        }

        let allowedSegmentCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encodedSegments = path.compactMap { $0.addingPercentEncoding(withAllowedCharacters: allowedSegmentCharacters) }
        guard encodedSegments.count == path.count else { throw APIError.invalidURL }

        let basePath = components.percentEncodedPath.hasSuffix("/")
            ? String(components.percentEncodedPath.dropLast())
            : components.percentEncodedPath
        components.percentEncodedPath = basePath + "/" + encodedSegments.joined(separator: "/")
        if !queryItems.isEmpty {
            components.queryItems = queryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<Response: Decodable & Sendable>(
        _ request: URLRequest,
        as responseType: Response.Type
    ) async throws -> Response {
        let response: HTTPTransportResponse
        do {
            response = try await transport.send(request)
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timedOut
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.transport
        }

        guard (200..<300).contains(response.statusCode) else {
            let code = try? makeDecoder().decode(APIErrorEnvelope.self, from: response.data).error.code
            throw APIError.httpStatus(statusCode: response.statusCode, code: code)
        }

        do {
            return try makeDecoder().decode(responseType, from: response.data)
        } catch {
            throw APIError.decoding
        }
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }
}

private struct APIErrorEnvelope: Decodable, Sendable {
    let error: ErrorBody

    struct ErrorBody: Decodable, Sendable {
        let code: String
    }
}
