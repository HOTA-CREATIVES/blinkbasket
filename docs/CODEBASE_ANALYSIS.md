# J C Mart (hypermart) — Codebase Analysis & Production Readiness Audit

> Generated 2026-07-18 by end-to-end reverse engineering of the repository (all statements grounded in code; file paths cited throughout). Verified against `flutter analyze` output and the actual Firestore rules/Cloud Functions test suites.

---

## 1. Executive Summary

| Item | Value |
|---|---|
| Product | **J C Mart** (Flutter package `hypermart`) — hyperlocal quick-commerce, COD-only, serving Bhimavaram + 4 villages |
| Personas | Customer, Delivery Partner (rider), Store Admin — single app, role-switched at login (`lib/app.dart` `AuthWrapper`) |
| Frontend | Flutter (Dart SDK ^3.7), Provider state management, Material 3, light/dark themes |
| Backend | Firebase serverless: Auth, Firestore, Cloud Functions v2 (TypeScript, `asia-south1`), FCM; Cloudinary for image hosting |
| Repo state | **1 commit** (`071b5f1`), large uncommitted working tree; CI configured (`.github/workflows/ci.yml`) |
| Overall implementation | **~85%** of the scoped product is built and wired end-to-end |
| Production readiness | **~55%** — see blockers below |

### 🔴 BLOCKER: the app does not compile

`flutter analyze` reports **18 errors**, all caused by **6 files that are imported but do not exist on disk** (an in-progress "promo banner + search" feature that was referenced but never committed):

| Missing file | Imported by |
|---|---|
| `lib/core/providers/banner_provider.dart` | `lib/main.dart:7` (registered in `MultiProvider` at line 68) |
| `lib/core/design/widgets/banner_carousel.dart` | `lib/modules/customer/screens/customer_home_screen.dart:4` |
| `lib/core/design/widgets/category_icon_rail.dart` | `customer_home_screen.dart:5` |
| `lib/core/design/widgets/delivery_eta_badge.dart` | `customer_home_screen.dart:6`, `product_details_screen.dart:6` |
| `lib/modules/customer/screens/search_screen.dart` | `customer_home_screen.dart:18` |
| `lib/modules/admin/screens/banner_management_screen.dart` | `lib/modules/admin/screens/admin_profile_screen.dart:12` |

Until these are created (or the imports/usages removed), `flutter run`, `flutter build`, and CI's `flutter analyze` step all fail. A `/banners` collection is already provisioned in `firestore.rules:130-133`, so the backend side of this feature exists.

### What is built (working when compiled)
- Full order lifecycle: catalog → cart → server-side `placeOrder` (transactional stock reservation + OTP) → admin rider assignment → rider swipe-progression → OTP-verified delivery → rating.
- 3-role auth with Firebase custom claims (`admin`, `delivery`) synced by Firestore triggers.
- Real-time inventory with `availableStock = physicalStock − reservedStock`, ledger writes to `/inventoryLogs`, admin stock adjustment UI.
- Dashboard stats aggregation via Firestore triggers; push notifications (FCM) for order status; rider earnings; OSM maps; admin biometric app-lock.
- Strong Cloud Functions + Firestore rules emulator test suite (~45 tests) wired into CI.

### What is partially built
- **Promo banners / search / ETA badge** — UI callers exist, 6 implementation files missing (the compile blocker).
- **Prescription medicines** — `requiresPrescription` flag flows through admin form → product DTO → customer messaging (`cart_screen.dart:184,321`), and `storage.rules:16-24` provisions `/prescriptions/{uid}` — but **no upload UI or enforcement exists anywhere in `lib/`**.
- **Node.js Express backend alternative** — `HttpOrderRepository` + `BackendConfig` (`useNodeBackend = false`) target `http://localhost:3000`, but **no backend/ directory exists in the repo**; dead branch.

### What is missing entirely
- Online payments (COD-only — by design per `docs/srs.md`), order search/filtering, admin analytics beyond 4 counters, Crashlytics/analytics, release signing config, i18n (Telugu region, English-only UI).

### Major non-compile blockers
1. **Rider-side features are blocked by security rules** (duty toggle, rider profile edit) — see §3.4.
2. **Missing composite index** for the inventory-logs-per-product query — runtime failure — see §4.3.
3. **Cloudinary API secret hardcoded in the client binary** — see §5.
4. **Hardcoded admin fallback account** (`admin@blinkbasket.com`) in `firebase_auth_repository.dart:163-174`.
5. Android release build signed with **debug keys**, applicationId still `com.example.hypermart` (`android/app/build.gradle.kts:26-41`).

---

## 2. UI Analysis

### 2.1 Screen inventory (24 screens on disk)

| Screen | Purpose | Route | Status | Backend connected | Missing items |
|---|---|---|---|---|---|
| `SplashScreen` (`core/utils/route_generator.dart:72`) | Boot/auth-resolution splash | `/` (also `home:` via `AuthWrapper`) | ✅ Done | n/a (waits on `AuthProvider`) | Hardcoded white bg/green colors (ignores theme tokens) |
| `UnifiedLoginScreen` (`auth/screens/unified_login_screen.dart`) | 3-role tabbed login shell | `AuthWrapper` unauthenticated | ✅ Done | Yes (via embedded role screens) | — |
| `CustomerLoginScreen` | Email/pass login + register tabs, Google sign-in | `/customer-login` | ✅ Done | Firebase Auth + Google | — |
| `DeliveryBoyLoginScreen` | Rider email login | `/delivery-login` | ✅ Done | Firebase Auth | — |
| `AdminLoginScreen` | Admin email login | (embedded in unified) | ✅ Done | Firebase Auth + `admins` lookup | — |
| `CustomerProfileSetupScreen` | First-run name/phone/village | `/customer-profile-setup` | ✅ Done | `users` doc create | — |
| `CustomerHomeScreen` | Catalog grid, category rail, cart badge, bottom nav | `AuthWrapper` role=customer | 🔴 **Broken (compile)** | `products` + `config/app` streams | `BannerCarousel`, `CategoryIconRail`, `DeliveryEtaBadge`, `SearchScreen` files missing |
| `SearchScreen` | Debounced product search, recent searches | pushed from home | ❌ **Missing file** | — | Entire file |
| `ProductDetailsScreen` | Hero image, qty stepper, similar products, share | `/product-details` | 🔴 **Broken (compile)** | `products` (similar rail) | `DeliveryEtaBadge` file missing |
| `CartScreen` | Cart lines, address select/map-pin, checkout | `/cart` | ✅ Done | `placeOrder` CF, `config/app` stream | — |
| `OrderSuccessScreen` | Animated check, shows delivery OTP | pushed after checkout | ✅ Done | `orders/{id}/private` OTP read | — |
| `OrderHistoryScreen` | Customer order list + reorder | `/order-history` | ✅ Done | `orders` stream | — |
| `OrderTrackingScreen` | 5-step timeline, cancel, rate, call rider, OTP display | pushed from history/success | ✅ Done | `orders/{id}` stream, rating write | — |
| `DeliveryHomeScreen` | Rider tabs: Tasks/Map/Earnings/Profile, duty toggle | `AuthWrapper` role=delivery | ⚠️ Duty toggle blocked by rules (§3.4) | `orders` by `deliveryBoyId` | — |
| `TaskDetailScreen` | Packing checklist, swipe-to-advance, OTP verify, call/map | `/task-detail` | ✅ Done | status update + `verifyDeliveryOtp` CF | — |
| `RiderMapScreen` | OSM map with active-delivery markers | `/rider-map` | ✅ Done | `orders` stream | — |
| `EarningsScreen` | COD collected, payout (config-driven ₹/delivery) | `/earnings` | ✅ Done | `orders` + `config/app` streams | — |
| `AdminHomeScreen` (3,568 lines) | Dashboard/Orders/Inventory/Riders tabs, biometric lock, add/edit product+rider sheets, assign-rider sheet, stock-adjust ledger sheet | `AuthWrapper` role=admin | ✅ Done | stats, orders, products, riders, `createRiderLogin` CF, Cloudinary | God-file; needs decomposition |
| `AddRiderScreen` | 2-step rider onboarding form | pushed | ✅ Done | `createRiderLogin` CF | — |
| `InventoryLogsScreen` | Last-50 ledger entries | pushed | ✅ Done | `inventoryLogs` stream | Icon map uses `release`/`cancel_release`/`stock_update` change-types never written (writers use `reserve`/`sale`/`return`/`restock`) |
| `StoreSettingsScreen` | Store open, fees, ETA label, payout, support numbers, categories | `/store-settings` | ✅ Done | `config/app` write | — |
| `AdminProfileScreen` | Admin settings incl. biometric toggle, banner mgmt link | **never navigated to** | 🔴 Broken + **dead code** | — | Imports missing `BannerManagementScreen`; no caller anywhere (`grep AdminProfileScreen(` → only its own definition) |
| `UserProfileScreen` | Shared profile (avatar, theme, addresses, support) | embedded in role homes | ⚠️ Partially blocked (§3.4) | Cloudinary avatar + profile writes | Admin/rider profile writes denied by rules |
| `AddressBookScreen` + `Add/Edit/DeleteAddressScreen` | CRUD addresses w/ map picker | pushed | ✅ Done | `users` doc update | — |

### 2.2 Reusable component library (`lib/core/design/widgets/`)
Present: `product_card`, `quantity_stepper`, `status_chip`, `empty_state`, `skeleton` (shimmer lists), `section_header`, `swipe_to_confirm_slider` (spring-back drag), `leaflet_location_picker` (OSM pin), plus `otp_verification_grid` (4-digit auto-advance + shake/vibrate) in delivery module. Missing: `banner_carousel`, `category_icon_rail`, `delivery_eta_badge` (referenced, not created).

### 2.3 UX state handling
- **Loading**: shimmer skeletons (`SkeletonList`) on orders/tracking; spinners elsewhere. ✅
- **Empty/error**: shared `EmptyState` (+ `EmptyState.error()`) used consistently. ✅
- **Animations**: order-success elastic check, swipe slider, OTP shake, parallax headers (admin profile banner). ✅
- **Theming**: `AppTokens` design tokens + light/dark `AppTheme`, user-selectable via `ThemeProvider`. ⚠️ Several rider/admin screens hardcode `Colors.white`/`grey.shade50`/`Colors.green` (e.g. `earnings_screen.dart:43-50`, `task_detail_screen.dart:110-117`, splash) — dark mode will render mixed.
- **Responsive**: phone-oriented layouts; no tablet/web breakpoints.

### 2.4 Navigation & protection
- Central `RouteGenerator` with 13 named routes; several screens pushed directly with `MaterialPageRoute` (OrderTracking, Search, AddRider, sheets) — mixed convention.
- **Route protection is implicit**: `AuthWrapper` picks the home per role, but named routes themselves have no role guard (e.g. any authenticated session could deep-link `/store-settings`; actual writes still blocked server-side by rules).

### 2.5 User flows (reverse-engineered)
1. **Customer**: Unified login → (register → profile setup) → Home (products/config streams) → Product details / Cart → address (saved/map-pin/village-centroid fallback, `cart_screen.dart:109-124`) → `placeOrder` CF → Success screen shows OTP → Track (timeline, cancel while pending/assigned, call rider) → Delivered → rate once.
2. **Rider**: Login (email must be whitelisted in `deliveryBoys`, UID locked on first login `auth_provider.dart:293-304`) → Tasks list → Task detail: check items → swipe `assigned→picked_up→out_for_delivery` → enter customer's 4-digit OTP → `verifyDeliveryOtp` CF marks delivered + decrements stock → Earnings.
3. **Admin**: Login (must exist in `admins`) → biometric/device-credential gate (`admin_home_screen.dart:60-92`) → Dashboard (live counters) → Orders queue → assign rider sheet → Inventory (add/edit/delete product, Cloudinary image upload, stock adjust w/ ledger) → Riders (search/filter, create login via CF, edit, soft-delete) → Store settings.

---

## 3. Backend Analysis

### 3.1 Cloud Functions (`functions/src/index.ts`, single file, region `asia-south1`)

| Export | Type | Functionality | Status |
|---|---|---|---|
| `placeOrder` | onCall | Validates auth/profile/active/store-open; item caps (50 items, 99 qty, no dupes); **service-area radius check** (12 km from village centroids, `index.ts:118-125`); transactional stock reservation + ledger write; server-side pricing/fees; creates order + private OTP doc | ✅ Complete, tested |
| `verifyDeliveryOtp` | onCall | Assigned-rider-only, `out_for_delivery` only, 5-attempt cap (counter survives rollback by design, `index.ts:278-306`); decrements physical+reserved stock, ledger `sale` entries, marks delivered | ✅ Complete, tested |
| `createRiderLogin` | onCall | Active-admin-only; creates Auth user + `deliveryBoys/{uid}` doc + `delivery` claim | ✅ Complete (no automated test) |
| `sendTestPush` | onCall | Admin-only FCM smoke tool | ✅ Complete (no automated test) |
| `onOrderWritten` | trigger | Active-order counter, revenue counter, stock release + `return` ledger on cancellation, push notifications | ✅ Complete, tested |
| `onRiderWritten` | trigger | Active-rider counter; syncs `delivery` custom claim (guarded `riderId.length > 20`) | ✅ Complete |
| `onProductWritten` | trigger | Product counter | ✅ Complete |
| `onAdminWritten` | trigger | Syncs `admin` custom claim from `admins/{uid}` | ✅ Complete |

**Weaknesses found:**
- All four stat triggers call `statsRef.update(...)` — `.update()` **throws if `config/dashboard_stats` does not exist**; nothing in the repo creates/seeds it (`SeederService` seeds products/config but is itself dead code — defined in `lib/core/services/seeder_service.dart`, never called).
- `placeOrder` ledger entries use `changeType: "reserve"` and `adminId: <customer uid>` (`index.ts:199-208`) — diverges from the documented taxonomy (`restock/sale/return/correction`) and overloads `adminId`.
- If the client omits `latitude`/`longitude`, the service-area check is **skipped** (`index.ts:118`) — an out-of-zone order with no coordinates is accepted.
- Orders are never expired: a `pending` order that no admin touches reserves stock forever (no scheduled/TTL function).

### 3.2 Flutter layering (matches CLAUDE.md architecture)

| Layer | Contents | Status |
|---|---|---|
| Providers (`lib/core/providers/`) | `AuthProvider` (role verify, UID-locking, FCM registration), `OrderProvider`, `ProductProvider`, `ConfigProvider`, `CartProvider` (in-memory, not persisted), `ProfileProvider`, `ThemeProvider` — **+ missing `BannerProvider`** | ⚠️ 7/8 |
| Use cases (`lib/domain/usecases/`) | 15 single-purpose classes (auth ×5, orders ×6, products ×3, +otp) | ✅ |
| Repository interfaces (`lib/domain/repositories/`) | `auth`, `order`, `product`, `config` | ✅ |
| Implementations (`lib/data/repositories/`) | `firebase_auth/order/product/config_repository`, `http_order_repository` (delegating shim) | ✅ |
| DTOs (`lib/data/models/`) | product, order, inventory_ledger, app_config, dashboard_stats | ✅ |

**Violations / debt:**
- UI instantiates concrete repositories directly: `order_history_screen.dart:11`, `order_tracking_screen.dart:14`, `product_details_screen.dart:10,28` (`FirebaseProductRepository()` inside widgets) — breaks the "UI → Provider → UseCase" flow and DI/testability.
- `admin_home_screen.dart` (3,568 lines) contains business flows (rider deletion guard `_hasActiveDeliveries`, stock adjust, product create) that belong in providers/usecases.
- `AuthProvider` news up its repository internally (`auth_provider.dart:24`) — untestable without Firebase.
- `HttpOrderRepository`/`BackendConfig` dead branch (no Node backend in repo).
- Project-guideline mismatch: the "Quick Commerce Guidelines" section of CLAUDE.md mandates **Riverpod + Freezed + Either<Failure,Success>**; the codebase uses **Provider + hand-written DTOs + Result classes/exceptions**. One of the two should be corrected.

### 3.3 AuthN / AuthZ / RBAC

- AuthN: Firebase email/password + Google Sign-In (`firebase_auth_repository.dart`), readable error mapping.
- RBAC: custom claims (`admin`, `delivery`) set by triggers; Firestore rules gate every collection on them (`firestore.rules:17-23`).
- Role-selection UX stores `selected_role` in SharedPreferences and re-verifies against the matching collection on each auth event.
- 🔴 **Backdoor**: `firebase_auth_repository.dart:163-174` fabricates an active admin `UserModel` for `admin@blinkbasket.com` when no `admins` doc matches ("local dev fallback"). Anyone who registers that email gets the admin UI (server rules still block privileged writes without the claim, but all signed-in-readable data + UI is exposed). Must be removed before release.
- ⚠️ Admin lookup also falls back to an email query on `admins` (`:151-160`), while `onAdminWritten` sets claims from the **doc ID**. An admin doc keyed by email would grant UI access but never a claim — doc-ID-as-UID must be the only convention (rules header says exactly this, `firestore.rules:6`).

### 3.4 🔴 Client writes that Firestore rules deny (broken features)

| Feature | Client write | Rule that denies it |
|---|---|---|
| Rider duty toggle (`delivery_home_screen.dart:127-135`) | updates `deliveryBoys/{uid}.isActive` as the rider | `firestore.rules:58-63` — riders may only change `uid`/`fcmTokens` |
| Rider profile edit / avatar (`ProfileProvider.updateProfileDetails` → `updateUserProfile` full `set()` on `deliveryBoys`) | rewrites whole doc | same `hasOnly(['uid','fcmTokens'])` constraint |
| Admin profile edit / avatar (same path → `admins` collection) | any write | `firestore.rules:46` — `admins` `write: if false` |
| Customer self-deactivation (`ProfileProvider.updateActiveStatus`) | changes `users/{uid}.isActive` | `firestore.rules:38` — `isActive` must be unchanged |
| Legacy rider UID-migration (`firebase_auth_repository.saveDeliveryBoyUid:184-197`) | **creates** `deliveryBoys/{authUid}` + **deletes** old doc | `firestore.rules:54` — create/delete admin-only. (Works only for riders provisioned via `createRiderLogin`, where docId == uid already.) |

These run silently in the UI today (errors are caught and shown as generic failures). Either relax the rules deliberately or route these through admin/Cloud-Function paths.

### 3.5 Dead / duplicate code
- Dead: `AdminProfileScreen` (no caller), `SeederService` (no caller), `HttpOrderRepository` node branch, `AuthProvider.addAddress/updateAddress/deleteAddress` (duplicated in `ProfileProvider`, which is what the address screens use).
- Duplicate: villages list exists in Dart (`lib/core/data/villages.dart`) and TS (`functions/src/index.ts:26-32`) — **documented intentional** duplication; drift risk acknowledged in a comment.
- No TODO/FIXME markers anywhere in `lib/` (clean), two Gradle template TODOs (`build.gradle.kts:26,38`).

---

## 4. Database Analysis (Cloud Firestore)

### 4.1 Collections & schemas (from DTOs, functions, rules)

| Collection | Doc ID | Key fields | Written by |
|---|---|---|---|
| `users/{uid}` | auth UID | name, email, phone, village, role=`customer`, isActive, addresses[] (embedded `AddressModel`), avatarUrl, fcmTokens[], createdAt | client (self), rules-constrained |
| `admins/{uid}` | auth UID (**must be**) | name, email, isActive | Firebase console only (`write: false`) |
| `deliveryBoys/{uid}` | auth UID | uid, name, email, phone, village, vehicleNo, licenseNo, isActive, isDeleted (soft delete), fcmTokens[] | `createRiderLogin` CF + admin client |
| `products/{id}` | auto | name, description, price(>0 enforced in rules), imageUrl (Cloudinary), category, unit, requiresPrescription, physicalStock, reservedStock, availableStock, stock (legacy mirror of available), lowStockThreshold, isActive | admin client + CFs (stock) |
| `orders/{id}` | auto | customerId/Name/Phone, deliveryAddress, village, lat/lng, items[] (frozen name/price/qty), subtotal, deliveryFee, totalAmount, paymentMethod=`COD`, status, deliveryBoyId/Name/Phone, rating, ratingComment, createdAt/updatedAt | `placeOrder` CF only (create); status by rules-scoped updates |
| `orders/{id}/private/delivery` | fixed | otp, attempts, createdAt | CF only; readable **only by the ordering customer** (`firestore.rules:110-114`) |
| `config/app` | fixed | storeOpen, deliveryFee, freeDeliveryAbove, etaLabel, riderPayoutPerDelivery, supportPhone, supportWhatsapp, categories[] | admin (StoreSettings) |
| `config/dashboard_stats` | fixed | activeOrdersCount, activeRidersCount, completedRevenue, productCount, lastUpdated | trigger CFs (⚠️ must pre-exist — see §3.1) |
| `inventoryLogs/{id}` | auto | productId, adminId, orderId?, changeType, physicalDelta, reservedDelta, notes, timestamp | CFs + admin client transaction |
| `banners/{id}` | — | (rules provisioned; no client code — feature incomplete) | — |

### 4.2 Order status machine (enforced in `firestore.rules:85-107`)
`pending → assigned → picked_up → out_for_delivery → delivered`, plus `pending|assigned → cancelled` (customer or admin). Riders advance exactly one step; `delivered` reachable only via the OTP Cloud Function. Rating: write-once, delivered-only.

### 4.3 Indexes (`firestore.indexes.json`)
- Present: `orders(customerId, createdAt desc)`, `orders(deliveryBoyId, createdAt desc)`.
- 🔴 **Missing**: `inventoryLogs(productId asc, timestamp desc)` — required by `FirebaseProductRepository.streamInventoryLogs` (`firebase_product_repository.dart:55-64`, used by the per-product ledger sheet in admin inventory). This query will fail at runtime with `failed-precondition` until the composite index is added.

### 4.4 CRUD status
Products: full CRUD (admin). Orders: create (CF) / read (scoped) / constrained updates / no delete. Users/addresses: full self-CRUD. Riders: create (CF), update/soft-delete (admin). Config: read-all/write-admin. InventoryLogs: append-only in practice. Banners: nothing client-side.

### 4.5 Data consistency notes
- Dual stock fields (`stock` legacy + 3-field model) kept in sync everywhere they're written; seeder (dead code) writes only legacy `stock` — DTO/CF fallbacks (`physicalStock ?? stock`) handle it.
- `inventoryLogs.changeType` vocabulary inconsistent across writers (`reserve`, `sale`, `return`, `restock`, admin-sheet free-form) vs. display map (`release`, `cancel_release`, `stock_update` in `inventory_logs_screen.dart:14-42`) — several real entries render with fallback icon.
- `deliveryBoys` uses both `isActive` (duty/enable) and `isDeleted` (soft delete); `streamAllDeliveryBoys` filters `isDeleted` client-side (`firebase_order_repository.dart:74-83`) — fine at this scale, unindexed at larger scale.

---

## 5. Integration Analysis

| Integration | Purpose | Configured | Working | Gaps |
|---|---|---|---|---|
| Firebase Auth | Email/pass + Google, 3 roles | ✅ (`firebase.json`, `google-services.json` present) | ✅ | Google Sign-In needs SHA-1 registered for release keystore (none exists yet) |
| Cloud Firestore | All data, offline persistence on (`main.dart:31-33`) | ✅ rules + partial indexes deployed config | ✅ | Missing composite index (§4.3) |
| Cloud Functions | 4 callables + 4 triggers, `asia-south1` | ✅ built (`functions/lib/index.js`) | ✅ | — |
| FCM push | Order-status + rider-assignment pushes; token registry per device (`push_notification_service.dart`); background handler + foreground SnackBar (`main.dart:20-47`) | ✅ | ✅ | Admins intentionally excluded; no notification deep-linking (tap does nothing with `orderId` payload) |
| Cloudinary | Product images + avatars (signed upload) | ✅ | ✅ | 🔴 `apiSecret` hardcoded client-side (`cloudinary_service.dart:8-11`) — full account compromise possible; folder named `testing-inventory`; **no env-var/remote-config indirection anywhere in the app** |
| Firebase Storage | `storage.rules` written for products + prescriptions | ⚠️ rules only | ❌ unused | No Dart code touches Storage — images go to Cloudinary; prescription upload absent |
| OpenStreetMap (`flutter_map`) | Rider map, location pickers | ✅ | ✅ | OSM tile-usage policy attribution should be verified for production |
| Geolocator / local_auth / share_plus / url_launcher | GPS, admin biometric lock, product share, tel/wa.me links | ✅ | ✅ | — |
| Node.js Express backend | Alternative order API (`BackendConfig`) | ❌ server absent from repo | ❌ | Dead code — remove or commit the server |
| Payments (Razorpay etc.) | — | ❌ | — | Out of scope: COD-only by design |
| Crashlytics / Analytics | — | ❌ | — | No crash or product analytics at all |

**Secrets/env status:** no `.env`, no `--dart-define` usage; the only secrets in the repo are the Cloudinary keys (leaked) and standard Firebase client keys (safe by design). CI needs no secrets (emulator-based).

---

## 6. Testing Analysis

### 6.1 Cloud Functions (Jest + emulators — strong)

| Suite | Tests | Covers |
|---|---|---|
| `functions/test/placeOrder.test.ts` | 9 | server-side pricing, free-delivery threshold, stock rejection, dupes, store-closed, item cap, unauthenticated, geo-fence in/out |
| `verifyDeliveryOtp.test.ts` | 6 | happy path + stock decrement, wrong OTP counter, 5-attempt lockout, wrong rider, wrong status, malformed OTP |
| `onOrderWritten.test.ts` | 3 | active count, revenue, cancellation stock release + ledger |
| `notifications.test.ts` | 4 | customer+rider pushes, no-token, messaging-failure isolation |
| `firestore.rules.test.ts` | 13 | order cancel/rate/step-forward rules, OTP privacy, rider self-registration constraints, user role-escalation block |

Run via `firebase emulators:exec` in CI (`ci.yml:41`). **Not covered:** `createRiderLogin`, `sendTestPush`, `onRiderWritten`/`onAdminWritten` claim sync, missing-`dashboard_stats` failure mode.

### 6.2 Flutter (thin)

| File | Tests | Covers |
|---|---|---|
| `test/widget_test.dart` | 1 | Splash smoke |
| `test/customer_flow_test.dart` | ~10 | `CustomerHelper` phone/village logic, `UserModel`/`OrderDto` serialization |
| `test/provider_usecase_test.dart` | ~7 | Product/Order/Config providers with mock repos (loading/error states) |

**Missing:** any real screen/widget test, `AuthProvider` role-verification logic (the most complex client code), cart math, reorder helper, golden tests, integration/E2E (no `integration_test/`, no Patrol/Maestro). ⚠️ `flutter test` currently passes only because no test imports the broken files — but CI still fails at the `flutter analyze` step.

### 6.3 Coverage estimate

| Area | Coverage |
|---|---|
| Cloud Functions business logic | ~85% |
| Firestore rules | ~80% (deliveryBoys duty-toggle denial and admins write-block untested) |
| Flutter providers/domain | ~25% |
| Flutter UI | <5% |

---

## 7. Tech Stack Analysis

| Technology | Installed | Configured | Used | Missing setup |
|---|---|---|---|---|
| Flutter (Dart ^3.7) + Material 3 | ✅ | ✅ | ✅ | — |
| provider ^6.1.2 | ✅ | ✅ | ✅ | (CLAUDE.md guideline says Riverpod — mismatch) |
| firebase_core/auth/cloud_firestore/messaging/cloud_functions | ✅ | ✅ | ✅ | — |
| google_sign_in | ✅ | ✅ | ✅ | Release SHA-1 |
| flutter_map + latlong2 | ✅ | ✅ | ✅ | — |
| geolocator, image_picker, local_auth, share_plus, url_launcher, shimmer, cached_network_image, google_fonts, flutter_svg, crypto, http, shared_preferences | ✅ | ✅ | ✅ | — |
| flutter_lints ^5 (`analysis_options.yaml`) | ✅ | ✅ | ✅ | Analyze currently red (missing files) |
| flutter_launcher_icons | ✅ | ✅ (`pubspec.yaml:117-120`) | ✅ | — |
| TypeScript 5.6 / firebase-functions v6 / firebase-admin v12 (Node 20) | ✅ | ✅ (`functions/tsconfig` implied, builds) | ✅ | — |
| Jest + ts-jest + rules-unit-testing + firebase-functions-test | ✅ | ✅ | ✅ | — |
| GitHub Actions CI (`.github/workflows/ci.yml`) | ✅ | ✅ (Flutter analyze/test + Functions emulator tests) | 🔴 failing (analyze) | No build/release job, no caching of emulators |
| Docker | ❌ | — | — | N/A for this stack |
| Git hooks / formatting automation | ❌ | — | — | None configured |
| freezed / build_runner | ❌ | — | — | Guideline says Freezed; not adopted |

**Config files present:** `firebase.json` (emulators: auth 9099, firestore 8090, functions 5001), `.firebaserc` (project `hypermart-ee8ef`), `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `google-services.json`, `lib/firebase_options.dart` (android/ios/macos/web/windows), lockfiles for both ecosystems.

---

## 8. Installation & Setup Status

| Service | Status | Working | Missing configuration |
|---|---|---|---|
| `flutter pub get` | ✅ (`pubspec.lock` present) | ✅ | — |
| `flutter analyze` | 🔴 18 errors | ❌ | Create/remove 6 missing banner/search files |
| `flutter run` / build | 🔴 | ❌ | Blocked by the same compile errors |
| `npm --prefix functions install` | ✅ (`package-lock.json`, `node_modules` present) | ✅ | — |
| `npm --prefix functions run build` | ✅ (`functions/lib/index.js` exists) | ✅ | — |
| Functions tests | ✅ | ✅ (needs Java for emulator; CI installs Temurin 21) | — |
| Firebase project | ✅ `hypermart-ee8ef` wired everywhere | ✅ | `config/app` + `config/dashboard_stats` docs must be seeded manually; first admin doc added via console |
| Android release | ⚠️ | ❌ | Debug signing config, `com.example.hypermart` appId, no keystore (`build.gradle.kts:26-41`) |
| iOS | ⚠️ config present (`firebase_options.dart` iOS app id, `Runner` project) | untested in repo | Push entitlements/APNs not verifiable from repo |
| Env/secrets | ❌ | — | No secret management at all; Cloudinary creds must be rotated & moved server-side |

**Bootstrap sequence for a new environment (reverse-engineered):** create Firebase project → enable email+Google auth → deploy rules/indexes/functions → console-create `admins/{uid}` for the first admin → seed `config/app` and `config/dashboard_stats` → run app.

---

## 9. Implementation Status by Module

### ✅ Completed
- Auth & RBAC (3 roles, claims, whitelists) — minus the dev backdoor to remove
- Order placement pipeline (CF, transactional stock, OTP, geo-fence)
- Delivery execution (tasks, swipe progression, OTP verify, map, earnings)
- Admin console (dashboard, order queue + assignment, product CRUD + image upload, stock ledger, rider management, store settings, biometric lock)
- Customer orders (history, tracking, cancel, rate, reorder)
- Profile & address book (customer)
- Push notifications (status + assignment)
- Cloud Functions test suite + CI pipeline definition

### ⚠️ Partial
- **Customer home & product details** — implemented but non-compiling due to missing widget files
- **Promo banners** — rules + UI hooks exist; provider/carousel/management screen missing
- **Search** — entry point wired; screen missing
- **Prescription products** — flag + messaging only; no upload/enforcement
- **Rider self-service** (duty toggle, profile edit) — UI exists, rules deny the writes
- **Flutter test suite** — skeleton only

### ❌ Missing
- Banner/search feature files (the 6 listed in §1)
- Payment gateway (by design), order expiry/timeout job, notification deep-links, analytics/crash reporting, release signing, i18n, admin profile management path

### 🔴 Broken
- Compile (whole app) — 6 missing files
- Per-product inventory ledger sheet — missing Firestore composite index
- `AdminProfileScreen` — dead + imports a missing file
- Rider duty toggle / rider & admin profile edits — rules-denied writes
- Legacy rider email-whitelist migration path (`saveDeliveryBoyUid`) — rules-denied create/delete

---

## 10. Code Quality Analysis

**Strengths**
- Clean Architecture layering is real, not aspirational (interfaces, use cases, DTO mapping) — with the handful of UI-repo violations noted in §3.2.
- Server-authoritative money and stock math; client totals explicitly labeled "preview" (`cart_screen.dart:105-106`).
- Thoughtful comments explaining *why* (OTP rollback trick, FCM background isolate, villages duplication).
- Consistent `Result`-style error wrappers at repository boundaries; no force-unwrap abuse observed; `context.mounted` checks after async gaps.
- Genuinely good rules suite — role escalation, field-smuggling, OTP privacy all tested.

**Debt / anti-patterns**
| Issue | Where | Impact |
|---|---|---|
| God file (3,568 lines) | `admin_home_screen.dart` | Unreviewable, unmergeable, untestable |
| Concrete repos constructed in widgets/providers | §3.2 list | Blocks unit testing, violates own CLAUDE.md rule |
| Duplicated address CRUD | `AuthProvider` vs `ProfileProvider` | Dead path + drift risk |
| Dead code | `AdminProfileScreen`, `SeederService`, Node-backend branch | Confusion, hides the real feature state |
| Hardcoded colors bypassing `AppTokens` | rider/admin screens, splash | Broken dark mode; violates own convention |
| Ledger changeType vocabulary drift | writers vs `inventory_logs_screen.dart` | Misleading audit UI |
| `stock` legacy field mirrored everywhere | products | Migration debt — remove after backfill |
| Cart state in-memory only | `CartProvider` | Cart lost on app restart (no persistence) |
| Client streams whole collections (`products`, `orders`, all riders) | repositories | Fine at village scale; add pagination/limits before growth |

**Scalability:** single-store, single-region model; stats via `FieldValue.increment` (write-contention safe for this volume); no pagination anywhere; `streamAllOrders` for admin will degrade with history growth (needs limit + date filtering).

---

## 11. Production Readiness Report

| Dimension | Score | Rationale |
|---|---|---|
| Architecture | **7.5/10** | Real layered design + server-authoritative core; god-file, DI violations, dead code deduct |
| UI completion | **80%** | 24/26 screens exist and are polished; 2 missing + 2 compile-broken + dark-mode inconsistencies |
| Backend completion | **90%** | All scoped functions/triggers done & tested; stats-doc fragility, no order-expiry |
| Testing coverage | **40%** overall | Functions ~85%, Flutter ~15%; no E2E |
| Integration completion | **75%** | Firebase+FCM+Cloudinary+OSM working; Storage unused, secrets unmanaged, no crash reporting |
| Security | **5/10** | Excellent rules & claims model **but**: leaked Cloudinary secret, admin backdoor account, debug-signed release, rules/client write mismatches |
| Scalability | **6/10** | Right pattern for a village-scale launch; unpaginated streams and single-doc stats are known ceilings |
| **Production readiness** | **~55%** | Not shippable today: does not compile; security items above are release-gating |

---

## 12. Missing Features, Action Items & Roadmap

### P0 — Unblock the build (hours)
1. Create the 6 missing files (or strip the banner/search/ETA usages): `banner_provider.dart`, `banner_carousel.dart`, `category_icon_rail.dart`, `delivery_eta_badge.dart`, `search_screen.dart`, `banner_management_screen.dart`. CI (`flutter analyze`) goes green again.
2. Add composite index `inventoryLogs(productId ASC, timestamp DESC)` to `firestore.indexes.json` and deploy.
3. Seed/guard `config/dashboard_stats` (switch triggers to `set(..., {merge:true})` or seed the doc).

### P1 — Security gate (before any release)
4. **Rotate the Cloudinary secret now** (it is in git history) and move signing to a Cloud Function (client should never hold `apiSecret`).
5. Delete the `admin@blinkbasket.com` fallback (`firebase_auth_repository.dart:163-174`).
6. Fix rules/client mismatches deliberately: rider duty toggle + rider profile edit (either extend `deliveryBoys` update rule to a safe field allowlist, or move through a callable); remove customer `updateActiveStatus` path; give admins a profile-edit path or remove the UI.
7. Android release: real applicationId, release keystore, register release SHA-1 for Google Sign-In.

### P2 — Product completeness (1–2 weeks)
8. Finish or descope prescription flow (upload to the already-ruled `/prescriptions/{uid}` Storage path + admin review gate before assignment).
9. Order-expiry scheduled function to release stock from stale `pending` orders.
10. Notification tap deep-linking (payload already carries `orderId`).
11. Decompose `admin_home_screen.dart` into per-tab files + move logic to providers; remove dead code (`AdminProfileScreen`, `SeederService`, Node-backend branch or commit the server).
12. Reconcile ledger `changeType` taxonomy across CF writers, admin sheet, and `inventory_logs_screen.dart`.

### P3 — Hardening (ongoing)
13. Flutter test debt: `AuthProvider` role-flow unit tests, cart math, widget tests for checkout/task flows; add an `integration_test/` smoke against emulators.
14. Crashlytics + basic analytics; OSM tile attribution/usage review.
15. Pagination/limits on admin order & ledger streams; persist cart locally.
16. Resolve the CLAUDE.md guideline contradiction (Provider vs Riverpod/Freezed) so future contributors follow one convention.

---

*Sources: full read of `lib/` (95 Dart files enumerated, all providers/repositories/entities and 20+ screens read), `functions/src/index.ts`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc`, both `package.json`/lockfiles, all 8 test files, `.github/workflows/ci.yml`, `android/app/build.gradle.kts`, `docs/` — cross-checked with `flutter analyze` (18 errors) and file-system verification of every missing import.*
