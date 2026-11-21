import Foundation

public struct EnquiryResponse: Equatable, Sendable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}
