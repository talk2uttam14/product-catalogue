import Foundation

func userFacingMessage(for error: Error) -> String {
    guard let apiError = error as? APIError else {
        return "Something went wrong. Please try again."
    }
    return apiError.errorDescription ?? "Something went wrong. Please try again."
}

func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    return (error as? URLError)?.code == .cancelled
}
