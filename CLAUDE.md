# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

J C Mart (package name `hypermart`) is a hyperlocal quick-commerce Flutter app on Firebase (BaaS), with real-time inventory adjustments and Cash-on-Delivery fulfillment across three personas: Customer, Delivery Partner, Store Admin.

## Commands

### Flutter app (root)
- Install deps: `flutter pub get`
- Run app: `flutter run`
- Analyze/lint: `flutter analyze`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/path/to/file_test.dart`
- Run a single test by name: `flutter test test/path/to/file_test.dart --plain-name "test description"`

### Cloud Functions (`functions/`, TypeScript)
- Install deps: `npm --prefix functions install`
- Build: `npm --prefix functions run build` (tsc)
- Run all tests: `npm --prefix functions test` (jest --runInBand --forceExit)
- Run a single test file: `npx --prefix functions jest test/placeOrder.test.ts`
- Local emulators (functions + firestore): `npm --prefix functions run serve`
- Deploy functions only: `npm --prefix functions run deploy`
- Tail function logs: `npm --prefix functions run logs`

## Architecture

Strict Clean Architecture with one-way dependency flow: UI → Provider → Domain (use cases) → Repository interface → Repository implementation → Firebase.

- `lib/modules/<feature>/` — Screens/widgets only. No business logic, no direct Firebase calls. Consume state via Providers.
- `lib/core/providers/` — `ChangeNotifier` state layer. Calls use cases/repositories and notifies listeners; no direct Firebase access.
- `lib/domain/entities/` — Plain business entities.
- `lib/domain/repositories/` — Abstract repository interfaces (contracts only).
- `lib/domain/usecases/<area>/` — Pure business logic, one class per use case (e.g. `place_order_usecase.dart`, `verify_delivery_otp_usecase.dart`).
- `lib/data/repositories/` — Concrete repository implementations (`firebase_*_repository.dart`, `http_order_repository.dart`) implementing the domain interfaces; handle DTOs and talk to Firestore/Cloud Functions.
- `lib/core/services/` — Cross-cutting Firebase/platform service wrappers.
- `lib/core/design/` — Design tokens (`app_tokens.dart`); `lib/core/theme/app_theme.dart` — light/dark themes. Never hardcode colors/spacing in UI — use these tokens.
- `lib/core/utils/route_generator.dart` — Central named-route generator.
- `lib/app.dart` — Root widget; `AuthWrapper` switches on `AuthProvider.status` (`uninitialized`/`unauthenticated`/`needsProfileSetup`/`authenticated`) and then on `currentUserModel.role` (`customer`/`delivery`/`admin`) to pick the persona's home screen.

Rule: all data access must go through a repository interface — never call Firebase/Firestore directly from providers or widgets.

### Cloud Functions (`functions/src/index.ts`)

Single-file functions module (region set via `REGION` constant). Key exports:
- `placeOrder`, `verifyDeliveryOtp`, `createRiderLogin`, `sendTestPush` — callable (`onCall`) functions.
- `onOrderWritten`, `onRiderWritten`, `onProductWritten`, `onAdminWritten` — Firestore triggers (`onDocumentWritten`) on `orders/{orderId}`, `deliveryBoys/{riderId}`, `products/{productId}`, `admins/{adminId}`.

Tests live in `functions/test/` (Jest + `@firebase/rules-unit-testing` for Firestore rules tests, `firebase-functions-test` for function unit tests).

### Core domain rules (enforced in both Flutter and Functions layers)

- **Stock formula**: `availableStock = physicalStock - reservedStock`. Any direct stock change must update all three fields together, inside a Firestore `runTransaction` (checkout race-condition safety).
- **Inventory ledger**: every stock adjustment must write an entry to `/inventoryLogs` with `productId`, `adminId` (or `system`), `changeType` (`restock`/`sale`/`return`/`correction`), `physicalDelta`, `reservedDelta`, `notes`, `timestamp`.
- **Admin-only writes**: `/products` and `/config` are writable only by users with the `admin` custom claim (`request.auth.token.admin == true`).
- **Pricing**: admin-only, strictly positive (`> 0.0`).
- **Store status gate**: checkout must check `/config/app.storeOpen == true` before processing.

## Coding conventions

- Prefer `const` constructors.
- No unused imports; use relative imports within feature modules.
- Never pass `BuildContext` across async gaps.
- Wrap all repository network/DB calls (Firebase, Cloud Functions, REST) in try/catch; return structured result wrappers (e.g. `Result<T>`) instead of throwing to the UI.
- Avoid `!` force-unwrap unless non-null is logically guaranteed; prefer optional chaining/fallbacks.

## Notable UI patterns

- Swipe-to-confirm slider (rider task updates): drag icon along a path, spring-back if released early.
- Auto-focus OTP input grid: 4-digit, auto-advance, vibration + shake animation on error.
- Shimmer skeletons matching target card dimensions during loading.
- Parallax header scaling on profile/product-detail screens.
# Quick Commerce Flutter + Firebase Guidelines

## Architecture & State Management
- Use Clean Architecture (presentation, domain, data layers).
- Use **Riverpod** for state management and local reactive caching.
- Use **Freezed** for data models and Firebase DTOs.

## Firebase Conventions
- Keep Firestore queries reactive using `.snapshots()` streams.
- Use **optimistic updates** for adding items to carts to reduce apparent latency.
- Never perform complex queries or aggregations on the client; use Cloud Functions.

## Formatting Rules
- Follow `flutter_lints` patterns.
- Always implement explicit error handling with `try-catch` blocks returning `Either<Failure, Success>`.
