# AI Usage Disclosure

## Tools used

- OpenAI Codex in the Codex desktop environment was used for architecture planning, implementation assistance, code review, integration checks, and documentation.
- The available project/session records do not identify a separate ChatGPT coding session or another AI tool. No model deployment/version identifier is recorded in the repository; none is invented here.

## Agent instructions and sources

- The project `AGENTS.md` was read and maintained as the repository engineering guide.
- `docs/architecture.md` was used as the approved architecture and API contract reference, then updated to describe the implementation actually copied into this submission.
- User-provided milestone briefs and independent review prompts directed backend foundation, Product and Enquiry modules, iOS foundation, concurrency hardening, SwiftUI screens, and backend/iOS integration.
- No other repository-local instruction file or installed coding-agent skill is recorded as used for implementation.

## Planning process

The work was split into reviewable milestones: approve architecture first; build the backend foundation; add product and enquiry modules; review the backend; build and harden the iOS foundation; implement screens; then verify the live backend, simulator, and Mailpit integration. The user approved the architecture and explicitly redirected iOS work to the completed Desktop Xcode project when multiple iOS copies existed.

## Key engineering prompts

1. **Architecture planning:** inspect the starting repository, propose a directory structure and API contracts, explain assumptions/trade-offs/testing, and wait for approval before implementation.
2. **Backend modules:** implement the Express/TypeScript foundation, Product repository/service/routes, and Enquiry service/email-provider boundary with strict validation and mocked tests.
3. **iOS foundation and hardening:** implement Swift 6 domain/network/repository/DI/ViewModel layers, then address cancellation races, duplicate enquiry submissions, URL scheme validation, and safe product-ID conversion.
4. **SwiftUI milestone:** implement reusable catalogue screens using the existing ViewModels and repositories without rewriting the foundation.
5. **Integration and review:** inspect actual API contracts and iOS wiring, exercise real HTTP and Mailpit delivery, run backend/Xcode verification, and only correct reproduced issues.

## AI mistakes and corrections

- An early UI test edit replaced the starter launch-performance test; the existing test was restored alongside the new coverage.
- The first opt-in integration UI test used a shell environment flag that Xcode did not pass into the test runner. The test result exposed the skip; the gate was changed to probe the local backend and Mailpit endpoints, and the live flow then passed.
- The first backend Supertest run inside the restricted command sandbox failed to bind local sockets (`EPERM`). Rerunning the same test suite with host access passed; this was an environment restriction rather than a code change.
- The app’s “service could not be reached” state was traced to no backend process listening on the configured local port. Starting the existing backend made health and product routes reachable; no API contract change was needed.
- The repository contained an older iOS foundation copy under Documents/Codex. The final package uses the user-designated Desktop app and does not include the older copy.

## Human ownership

The user approved the architecture and provided milestone direction, including independent review requests and the Desktop project location. AI-assisted changes were built and tested, including real local HTTP and Mailpit checks. The final consolidated repository is prepared for the user’s review; this disclosure does not claim external reviewer acceptance or a submitted pull request.

## Time spent

Time was not tracked during this AI-assisted milestone sequence, so no estimate is reported.
