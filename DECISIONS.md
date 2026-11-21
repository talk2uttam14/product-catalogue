# Engineering Decisions

This record describes decisions visible in the implementation. It does not add requirements beyond the approved MVP.

## Technology choices

- **Swift and SwiftUI:** Native iOS UI with value-oriented views and the Observation framework. Swift 6 strict concurrency checking is enabled.
- **Node.js, Express, and TypeScript:** A small HTTP service with explicit route, service, and adapter boundaries. Strict compiler settings catch unsafe assumptions without adding a framework.
- **URLSession and async/await:** Built-in networking with typed request/response handling and cancellation, avoiding a third-party client.
- **MVVM:** Each screen observes a feature ViewModel that owns loading, result, validation, and submission state; views render state and collect input.
- **Repository pattern:** ViewModels depend on repository protocols. iOS repositories depend on `APIClient`; backend services depend on `ProductRepository` and `EmailProvider` abstractions.
- **Dependency injection:** Constructor injection keeps app composition explicit, permits test doubles, and avoids global service singletons or a DI framework.
- **Nodemailer and Mailpit:** SMTP acceptance is a replaceable delivery boundary. Mailpit offers local capture without real recipients or credentials.

## Assumptions and behavior

- **Featured selection:** The backend sorts rating descending, rating count descending, then product ID ascending, and returns up to five products.
- **Category ranking:** Each category uses the same three-part ranking. The first five form `featured`; the remaining products form `remaining`. Service-level ID deduplication keeps the partitions disjoint.
- **Search:** The backend trims the query and performs case-insensitive substring matching over title, description, and category. Results are ordered by product ID ascending. Empty or invalid queries return validation errors.
- **Product metadata:** Product responses include string ID, title, description, category, image URL, numeric price, and rating rate/count. The UI displays the image, title, price, rating, category, and description where relevant.
- **Enquiry fields:** Name, email, and message are required; phone is optional. The backend is authoritative and enforces name up to 100 characters, email up to 254, phone up to 30, and message up to 2,000. The iOS ViewModel mirrors these usability checks.
- **Product ID conversion:** Catalogue IDs remain strings in the product domain. The enquiry boundary converts only canonical positive decimal IDs that fit JavaScript’s safe integer range; invalid IDs produce a user-safe validation message.
- **Success:** `201 Created` means the configured SMTP provider accepted the message. It does not promise final inbox delivery.
- **Delivery failure:** SMTP errors become a generic `502 EMAIL_DELIVERY_FAILED` response; internal provider details are not returned.
- **Source errors:** Fake Store network, timeout, HTTP, and invalid-payload failures are translated into a generic product-source error.

## Extensibility

- **Replace product source:** Implement the `ProductRepository` interface and inject it from the backend composition root. `ProductService` does not depend on Fake Store API.
- **Replace email provider:** Implement `EmailProvider` and update backend composition. The enquiry service remains independent of Nodemailer.
- **Change UI styling:** Reusable cards, category chips, grids, and load-state views live in the iOS design-system directory; individual screens can adopt shared style changes.
- **Extend catalogue behavior:** Add a focused service operation, route, repository contract method where needed, and matching iOS domain/repository/view-model flow. Keep transport DTO mapping at repository boundaries.
- **Add features:** Create a feature screen and ViewModel, inject existing domain-facing repositories, and extend the versioned API only when an approved requirement needs it.

## Trade-offs

- A short in-memory cache and in-flight request sharing reduce repeated upstream requests. The cache is process-local, volatile, and has no invalidation endpoint; this matches the small single-process assessment.
- Search and category endpoints return the full small assessment dataset without pagination. Search has no ranking or typo tolerance.
- Enquiry email delivery is synchronous so confirmation follows provider acceptance. There is no queue, retry policy, or persistence.
- Mailpit is a local test service, not a production mail server. The implementation uses environment-based SMTP configuration and can be pointed at another provider.
- iOS integration uses the local simulator host by default. Physical-device networking requires an HTTPS backend configuration and was not verified here.

## Requirements intentionally out of scope or simplified

- Database persistence, authentication, authorization, payments, administration, queues, and microservices are not implemented, per the approved MVP scope.
- Product pagination, advanced search relevance, typo correction, and catalogue editing are not implemented.
- A production SMTP account, retry/delivery tracking, and inbox guarantees are not implemented.
- A distributable production build, CI pipeline, and physical-device networking setup are not included.

## If another day were available

1. Add a reproducible CI job for backend checks and simulator builds/tests, with the live integration test kept opt-in.
2. Add stronger offline UI coverage for category partition presentation and the enquiry success/error views using deterministic test fixtures.
3. Add operational request IDs and narrowly scoped backend diagnostics while preserving generic client errors and avoiding personal data in logs.
4. Add pagination only if the product source grows beyond the current assessment dataset.
5. Configure and verify a production HTTPS deployment and production email adapter only after deployment requirements are known.
