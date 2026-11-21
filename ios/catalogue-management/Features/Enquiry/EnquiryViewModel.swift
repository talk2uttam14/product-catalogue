import Foundation
import Observation

public enum EnquirySubmissionState: Sendable {
    case idle
    case submitting
    case succeeded(EnquiryResponse)
    case failed(String)
}

@MainActor
@Observable
public final class EnquiryViewModel {
    public private(set) var state: EnquirySubmissionState = .idle
    private let repository: any EnquiryRepository

    public init(repository: any EnquiryRepository) {
        self.repository = repository
    }

    public func submit(_ request: EnquiryRequest) async {
        if case .submitting = state { return }
        await submitValidated(request)
    }

    public func submit(
        product: Product,
        name: String,
        email: String,
        phone: String? = nil,
        message: String
    ) async {
        if case .submitting = state { return }
        do {
            let request = try EnquiryRequest(
                product: product,
                name: name,
                email: email,
                phone: phone,
                message: message
            )
            await submitValidated(request)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func submitValidated(_ request: EnquiryRequest) async {
        if let validationMessage = validationMessage(for: request) {
            state = .failed(validationMessage)
            return
        }

        state = .submitting
        do {
            let response = try await repository.submit(request)
            try Task.checkCancellation()
            state = .succeeded(response)
        } catch {
            if isCancellationError(error) {
                state = .idle
                return
            }
            state = .failed(userFacingMessage(for: error))
        }
    }

    private func validationMessage(for request: EnquiryRequest) -> String? {
        let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = request.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = request.message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard request.productId > 0, request.productId <= EnquiryRequest.maximumSafeProductID else {
            return "Select a valid product."
        }
        guard !name.isEmpty, name.utf16.count <= 100 else { return "Enter a name of up to 100 characters." }
        guard email.utf16.count <= 254, Self.isValidEmail(email) else { return "Enter a valid email address." }
        guard !message.isEmpty, message.utf16.count <= 2_000 else { return "Enter a message of up to 2,000 characters." }

        if let phone = request.phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            guard phone.utf16.count <= 30 else { return "Phone must be 30 characters or fewer." }
            let normalizedPhone = phone.filter { !$0.isWhitespace && !"().-".contains($0) }
            let digits = normalizedPhone.dropFirst()
            guard normalizedPhone.first == "+",
                  (8...15).contains(digits.count),
                  digits.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                  digits.first != "0"
            else {
                return "Enter an international phone number."
            }
        }

        return nil
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]*[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]*[A-Z0-9])?)+$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
