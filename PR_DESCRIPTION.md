# Product Catalogue MVP

## Overview

This submission combines the completed SwiftUI catalogue application and its Express/TypeScript backend in one repository. The iOS client communicates only with the versioned backend API; the backend obtains products from Fake Store API and delivers enquiries through SMTP.

## Features

- Home screen with featured products and category navigation.
- Category browsing with top-rated and remaining product groups.
- Search across product title, description, and category.
- Product detail and enquiry form with confirmation after accepted delivery.
- Backend product endpoints and synchronous enquiry email workflow.

## Architecture

The iOS app uses Swift 6, SwiftUI, Observation, MVVM, repositories, URLSession async/await, and an injected AppContainer. The backend separates routes, services, repositories, and email provider behind interfaces. In-memory caching is process-local and time-limited. See `docs/architecture.md`.

## Engineering decisions

Featured ranking uses rating descending, rating count descending, then ID ascending. Category ranking uses rating descending and ID ascending. Enquiry submission is acknowledged only after SMTP accepts the email; enquiries are not persisted. See `DECISIONS.md` for assumptions and trade-offs.

## Verification

- Backend: `npm test` (42 tests), `npm run typecheck`, and `npm run build` passed in the consolidated repository.
- iOS: generic iOS Simulator build passed; the full iPhone 18 Pro suite previously passed (33 tests, 0 failures). A repeat test run after the final tab bar adjustment was attempted but CoreSimulator stalled before reporting a result.
- A live product-to-enquiry UI flow against local backend and Mailpit produced the screenshots in `docs/screenshots/`.

## Assumptions and limitations

- This is an MVP without database persistence, authentication, payments, administration, queues, or production deployment.
- Enquiries depend on an available SMTP server. Mailpit is the documented local development option.
- iOS deployment target follows the project’s configured iOS 18.6 target.
- Physical device connectivity and production email delivery were not verified.

## AI usage

OpenAI Codex assisted with planning, implementation, review, and documentation. The user retained ownership of the solution and directed milestone scope. `AI_USAGE.md` records prompts and verifiable corrections; model/version details are omitted where unavailable.
