import Foundation

public struct EnquiryRepositoryImplementation: EnquiryRepository {
    private let apiClient: any APIClient

    public init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    public func submit(_ request: EnquiryRequest) async throws -> EnquiryResponse {
        let response: DataEnvelope<EnquiryResponseWireDTO> = try await apiClient.post(
            ["api", "v1", "enquiries"],
            body: EnquiryRequestWireDTO(request),
            as: DataEnvelope<EnquiryResponseWireDTO>.self
        )
        return EnquiryResponse(status: response.data.status)
    }
}

private struct EnquiryRequestWireDTO: Encodable, Sendable {
    let productId: Int
    let name: String
    let email: String
    let phone: String?
    let message: String

    init(_ request: EnquiryRequest) {
        productId = request.productId
        name = request.name
        email = request.email
        phone = request.phone
        message = request.message
    }
}

private struct DataEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
}

private struct EnquiryResponseWireDTO: Decodable, Sendable {
    let status: String
}
