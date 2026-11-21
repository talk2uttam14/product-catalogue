import SwiftUI

struct CatalogueLoadStateView<Value: Sendable, Content: View>: View {
    let state: LoadState<Value>
    let emptyTitle: String
    let emptyMessage: String
    let retry: () -> Void
    let content: (Value) -> Content

    init(
        state: LoadState<Value>,
        emptyTitle: String,
        emptyMessage: String,
        retry: @escaping () -> Void,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.retry = retry
        self.content = content
    }

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView("Loading catalogue…")
                .frame(maxWidth: .infinity, minHeight: 220)
                .accessibilityIdentifier("catalogue.loading")
        case let .loaded(value):
            content(value)
        case .empty:
            ContentUnavailableView(emptyTitle, systemImage: "shippingbox", description: Text(emptyMessage))
                .frame(maxWidth: .infinity, minHeight: 240)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn’t load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }
}
