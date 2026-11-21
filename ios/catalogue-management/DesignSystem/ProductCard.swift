import SwiftUI

struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                case .empty:
                    ProgressView()
                        .accessibilityLabel("Loading product image")
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Product image unavailable")
                @unknown default:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 164)
            .background(.quaternary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(product.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)

            HStack(alignment: .firstTextBaseline) {
                Text(product.price.formatted(.currency(code: "USD")))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Label(product.rating.rate.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("Rated \(product.rating.rate.formatted(.number.precision(.fractionLength(1)))) out of 5")
            }
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.045), radius: 8, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
