import SwiftUI

struct EnquiryScreen: View {
    let container: AppContainer
    let product: Product
    @State private var viewModel: EnquiryViewModel
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var message = ""
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer, product: Product) {
        self.container = container
        self.product = product
        _viewModel = State(initialValue: EnquiryViewModel(repository: container.enquiryRepository))
    }

    var body: some View {
        Group {
            if case .succeeded = viewModel.state {
                thankYou
            } else {
                enquiryForm
            }
        }
        .navigationTitle("Product enquiry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var enquiryForm: some View {
        Form {
            Section("Product") {
                HStack(spacing: 12) {
                    AsyncImage(url: product.imageURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 54, height: 54)
                    .padding(6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(product.price.formatted(.currency(code: "USD")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Section("Your contact details") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("enquiry.name")
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("enquiry.email")
                TextField("Phone (optional)", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .accessibilityIdentifier("enquiry.phone")
            }

            Section {
                TextEditor(text: $message)
                    .frame(minHeight: 130)
                    .accessibilityLabel("Message")
                    .accessibilityIdentifier("enquiry.message")
                HStack {
                    Text("Please share what you’d like to know.")
                    Spacer()
                    Text("\(message.utf16.count)/2,000")
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Message")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("enquiry.error")
                }
            }

            Section {
                Button(action: submit) {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                            Text("Sending…")
                        } else {
                            Label("Send enquiry", systemImage: "paperplane.fill")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
                .accessibilityIdentifier("enquiry.submit")
            } footer: {
                Text("We’ll use these details to respond to your enquiry.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var thankYou: some View {
        ContentUnavailableView {
            Label("Thank you", systemImage: "checkmark.seal.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
        } description: {
            Text("Your enquiry about \(product.title) has been sent. We’ll be in touch soon.")
        } actions: {
            Button("Back to product", systemImage: "arrow.left") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier("enquiry.thankYou")
    }

    private var isSubmitting: Bool {
        if case .submitting = viewModel.state { return true }
        return false
    }

    private var errorMessage: String? {
        if case let .failed(message) = viewModel.state { return message }
        return nil
    }

    private func submit() {
        Task {
            await viewModel.submit(
                product: product,
                name: name,
                email: email,
                phone: phone,
                message: message
            )
        }
    }
}
