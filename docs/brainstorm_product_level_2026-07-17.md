# J C Mart — Brainstorm: Getting to "Product Level"

*Continuous discovery ideation · 2026-07-17*
*Grounded in codebase research: 25 screens, Firestore data models, Cloud Functions (`functions/src/index.ts`), and confirmed gaps (no notifications, no search, no promo model, single flat `config/app` doc).*

---

## Objective

Take J C Mart from a solid, transaction-safe pilot MVP to a **product-level** hyperlocal quick-commerce platform: retention-ready, operationally tunable without redeploys, and resilient at multi-village scale.

---

## 1. Product Manager Perspective (business value, strategic alignment, customer impact)

1. **Order-status push notifications** — Wire `firebase_messaging` to the existing `onOrderWritten`/`verifyDeliveryOtp` triggers so status changes (`assigned`, `out_for_delivery`, `delivered`) reach the customer and rider even with the app backgrounded. This is the single highest-leverage retention/trust lever — right now the product is invisible the moment the app closes.
2. **Reorder-in-one-tap** — The rating card already sits on a delivered order in `order_tracking_screen.dart`; extend it to surface a "Reorder" action that re-adds the same cart. Turns a passive rating moment into a repeat-purchase moment for a low-consideration grocery category.
3. **Per-village store config** — Split the flat `config/app` doc into per-village documents (fee, ETA label, store-open) so ops can open Bhimavaram while keeping Rayakuduru closed, or run different delivery fees per zone as new villages onboard. Directly unblocks geographic expansion, which is the platform's stated growth axis.
4. **Low-stock-to-reorder supplier loop** — `lowStockThreshold` already exists on `Product` and is shown in the admin UI; turn it into an actionable signal — a daily digest (email or in-app) admins can act on before a SKU goes to zero and blocks conversion.
5. **Prescription/OTC vertical activation** — `requiresPrescription` is modeled but has no upload/verification flow. Either build the minimal flow (image upload + admin approval gate before `placeOrder` accepts the item) or remove the field — right now it's a half-built promise sitting in the schema that could mislead a future engineer into thinking it's live.

## 2. Product Designer Perspective (UX, usability, delight)

1. **In-app help/support surface** — There is no support screen anywhere in the 25-screen inventory. A COD hyperlocal app *will* generate "where's my order," "wrong item," "rider hasn't shown" tickets — right now a customer's only recourse is leaving the app. Even a simple WhatsApp/call-to-admin deep link from `order_tracking_screen` closes a real gap.
2. **Search-as-you-type on the catalog** — `customer_home_screen.dart` is category-only navigation today. A lightweight client-side filter (no backend change needed — catalog sizes at pilot scale fit in memory) is a small UI investment with outsized usability payoff as SKU count grows past what fits on one scroll.
3. **Delivery ETA countdown, not just a status label** — `AppConfig.etaLabel` is a static admin-set string today ("Delivers in ~20 min"). Pair it with a live countdown/progress bar on `order_tracking_screen` once the order is `out_for_delivery`, using timestamps already captured (`updatedAt`) — makes the wait feel bounded without needing live GPS.
4. **Rider-side outdoor-readability pass on `task_detail_screen`** — SRS calls for "high contrast for outdoor usage" as a constraint; worth a dedicated design audit of the delivery module specifically (current swipe-slider and OTP grid look solid, but a contrast/legibility check under direct sunlight is a cheap, high-value QA pass before wider rider rollout).
5. **Empty-state and first-order onboarding polish** — With `EmptyState`/`Skeleton` design-system widgets already built (`core/design/widgets/`), audit which screens (address book, order history, inventory logs) actually use them vs. show a blank list — consistency here is mostly wiring, not new design work.

## 3. Software Engineer Perspective (technical leverage, data, scalability)

1. **Firestore rules + Functions emulator test suite** — The most business-critical, transaction-heavy code (`placeOrder`, `verifyDeliveryOtp`, stock-reservation math) currently has zero automated coverage; existing tests only cover `CustomerHelper`/`UserModel`. `@firebase/rules-unit-testing` + the Functions emulator would catch regressions in the exact code path that touches money and inventory.
2. **Server-side delivery-zone validation** — `placeOrder` accepts client-supplied `latitude`/`longitude` with no check against the whitelisted village/service-area list. `CustomerHelper.findClosestVillage` logic already exists client-side; move an equivalent check into the transaction so an out-of-zone order can't be placed at all, not just discouraged by UI.
3. **Config-driven rider payout** — `EarningsScreen` hardcodes ₹30/delivery in Dart. Move it to `config/app` (mirroring how `deliveryFee`/`freeDeliveryAbove` are already done correctly) so payout changes don't require an app store release.
4. **Crash/error observability** — No Crashlytics/Sentry/Analytics dependency anywhere. Given the transaction-heavy checkout path, blind production incidents (a failed `placeOrder` transaction, a stuck OTP) are currently invisible until a user complains. This is a low-effort, high-diagnostic-value addition.
5. **Retire or productionize the dual-backend flag** — `BackendConfig.useNodeBackend` and the parallel `http_order_repository.dart` are a dev-only escape hatch to a local Node/Express backend, hardcoded off for production. Worth a decision: delete the dead path to reduce surface area, or document why it's kept (e.g., planned migration off Cloud Functions) — right now it's ambiguous which.

---

## 4. Prioritized Top 5

| # | Idea | Perspective | Why prioritized | Key assumptions to validate |
|---|---|---|---|---|
| 1 | **Order-status push notifications** | PM | Highest-leverage single change: closes the biggest gap between "works" and "trusted" for a delivery-time-sensitive app; hooks directly into triggers that already exist (`onOrderWritten`, `verifyDeliveryOtp`) — mostly wiring, not new business logic. | Customers/riders will grant notification permission; FCM token lifecycle (refresh, multi-device) can be added without disrupting existing auth flow. |
| 2 | **Firestore rules + Functions emulator tests** | Engineer | Protects the exact code path (stock reservation, OTP, payout math) that is both most business-critical and least covered — a regression here is a revenue/trust incident, not a cosmetic bug. | Team has bandwidth to write and maintain emulator-based tests; CI can run the Firebase emulator suite without major pipeline rework. |
| 3 | **Server-side delivery-zone validation** | Engineer | Currently a silent trust gap — the transaction that moves money and reserves stock doesn't verify the order is even deliverable. Reuses existing `findClosestVillage`-style logic, just relocated into the transaction. | The whitelisted village list is complete/current enough to gate orders without false-rejecting legitimate addresses near village boundaries. |
| 4 | **Config-driven rider payout** | Engineer/PM | Smallest effort item on this list (mirrors an already-correct pattern for `deliveryFee`) but directly unblocks a real operational pain point — today a payout change requires a full app release. | Payout stays flat-rate-per-delivery for now (no per-distance/per-village tiering yet) — if ops wants tiering, this needs a slightly richer config shape. |
| 5 | **In-app help/support surface** | Designer | Zero-cost-to-discover gap (literally absent from all 25 screens) in a product category that reliably generates support needs ("where's my order," wrong item, no-show rider); even a minimal WhatsApp/call deep-link meaningfully reduces churn from unresolved friction. | A manual/human-staffed channel (WhatsApp, phone) is acceptable at pilot scale — no need for a full ticketing system yet. |

---

### Sequencing note

Items 2–4 are backend/data hardening that can ship in parallel without user-facing risk. Item 1 (notifications) is the biggest lift (new dependency, platform permissions, FCM token management) and should be scoped as its own initiative. Item 5 can ship independently as a near-zero-risk UI addition at any point in the sequence.
