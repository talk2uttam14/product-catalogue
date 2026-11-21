import Foundation

public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}
