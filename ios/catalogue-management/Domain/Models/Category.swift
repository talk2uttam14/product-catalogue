import Foundation

public struct Category: Equatable, Hashable, Identifiable, Sendable {
    public let name: String
    public var id: String { name }

    public init(name: String) {
        self.name = name
    }
}
