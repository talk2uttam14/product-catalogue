import Foundation

public protocol EnquiryRepository: Sendable {
    func submit(_ request: EnquiryRequest) async throws -> EnquiryResponse
}
