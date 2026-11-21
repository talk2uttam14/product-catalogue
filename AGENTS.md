# Repository Instructions

## Project architecture

This repository contains the approved Product Catalogue MVP.

- iOS: Swift 6, SwiftUI, Observation (`@Observable`), iOS deployment target 18.6, MVVM, repository protocols, constructor-based DI, URLSession, and async/await.
- Backend: Node.js, Express, strict TypeScript, dependency injection, application services, repository/provider interfaces, Vitest, and Supertest.
- iOS talks only to the backend. Fake Store API is accessed only by `backend/src/products/fake-store-product.repository.ts`.
- Product source and email delivery remain replaceable behind `ProductRepository` and `EmailProvider`.
- Local email development uses Nodemailer with Mailpit SMTP.
- Follow `docs/architecture.md` and `DECISIONS.md` for actual request, response, and design behavior.

## Product/API rules

- Home loads category navigation and up to five featured products.
- Featured and category ranking is rating descending, rating count descending, then product ID ascending.
- `GET /api/v1/categories/:category/products` returns up to five products in `featured` and all remaining products once in `remaining`.
- Search matches title, description, or category case-insensitively. Register the fixed search route before `GET /products/:id`.
- Product API IDs are strings. Enquiry `productId` is a positive JavaScript-safe JSON integer.
- Enquiry name, email, and message are required; phone is optional. Backend validation is authoritative. Do not show thank-you until provider acceptance.
- Preserve the `/api/v1` contracts. Present any proposed API contract change for approval before implementing it.

## Coding standards

- Keep types cohesive and abstractions at actual replacement boundaries. Avoid speculative frameworks, layers, dependencies, and unrelated refactors.
- Keep domain models independent of transport and vendor payloads; map them at repository boundaries.
- Keep Express handlers thin. Validate input, invoke services, and use established response envelopes.
- Use constructor injection and the existing composition roots. Do not introduce global singletons or a second DI mechanism.
- Use async/await, propagate errors deliberately, and keep asynchronous UI state on the appropriate actor.
- Explain non-obvious implementation decisions in code comments or the change summary.
- Keep reusable UI and styling in the small shared design system.

## Swift 6 concurrency

- Keep Swift 6 language mode and complete strict-concurrency checking enabled.
- Resolve diagnostics through correct actor isolation and ownership.
- Do not use `@unchecked Sendable`, force unwraps, `try!`, or concurrency-warning suppressions.
- Preserve cancellation behavior and guard against stale responses for overlapping requests.

## Security

- Never commit real API keys, SMTP credentials, customer data, local `.env` files, certificates, or provisioning profiles.
- Read environment-specific SMTP and backend configuration through config/build settings; keep `.env.example` placeholder-only.
- Validate and bound client input and JSON request size. Treat upstream payloads as untrusted.
- Return generic client-facing errors for upstream, SMTP, and unexpected failures. Do not expose provider diagnostics, internal hosts, or stacks.
- Do not log enquiry message contents or unnecessary personal data.
- Keep product-source URLs out of iOS code.

## Testing and reporting

- Backend: `npm test`, `npm run typecheck`, and `npm run build`.
- iOS: build the actual Xcode project and run XCTest, Swift Testing, and UI tests. The live-services UI flow needs the local backend, reachable Fake Store API, and Mailpit; report when it skips.
- Prefer fakes/mocked transport for routine tests. Do not make backend or iOS unit tests depend on live Fake Store or SMTP.
- Report exact commands actually run and observed results. Never claim a test passed unless it was executed; distinguish skips and environment failures from code failures.

## Scope and collaboration

- Preserve existing source, assets, project settings, schemes, tests, and user changes.
- Do not modify unrelated files or discard changes.
- No database, authentication, payments, admin panel, queues, microservices, or unnecessary frameworks are in MVP scope.
- Prepare local changes and a reviewable PR description when requested. Do not push or create a remote PR without explicit approval.
