# J C Mart — Implementation Plan

> Companion to [CODEBASE_ANALYSIS.md](CODEBASE_ANALYSIS.md) (2026-07-18). Fixes every identified error, completes the UI, closes the functionality gaps, and hardens the integrations. Phases are ordered by dependency; each has explicit file-level work items and acceptance criteria. Constructor signatures below are derived from the **actual call sites** in the existing code, so the new files drop in without touching callers.

**Sequencing overview**

```
Phase 0  Restore compilation (banner/search/ETA files)      ~1 day      ── unblocks everything
Phase 1  Runtime blockers (index, stats doc, dead screen)   ~0.5 day    ── after 0
Phase 2  Security hardening (secrets, backdoor, rules)      ~2–3 days   ── parallel with 1
Phase 3  Functionality completion                           ~1–2 weeks  ── after 0–2
Phase 4  Integrations                                       ~2–3 days   ── parallel with 3
Phase 5  Testing & CI                                       continuous  ── starts after 0
```

---

## Phase 0 — Restore compilation (P0, ~1 day)

Goal: `flutter analyze` → 0 errors; CI green. Six files to create. The banner feature gets a full Clean-Architecture vertical slice (rules for `/banners` already exist in `firestore.rules:130-133`).

### 0.1 Banner data slice (4 new files + 1 provider)

| # | New file | Contents |
|---|---|---|
| 1 | `lib/domain/entities/banner_item.dart` | `class BannerItem { final String id; final String imageUrl; final String? category; final bool isActive; final int sortOrder; final DateTime createdAt; }` (named `BannerItem` to avoid clashing with Material's `Banner` widget) |
| 2 | `lib/domain/repositories/banner_repository.dart` | `abstract class BannerRepository { Stream<List<BannerItem>> streamActiveBanners(); Stream<List<BannerItem>> streamAllBanners(); Future<void> addBanner(BannerItem b); Future<void> updateBanner(BannerItem b); Future<void> deleteBanner(String id); }` |
| 3 | `lib/data/models/banner_dto.dart` | `fromMap`/`toMap`/`fromEntity`, defensive defaults matching `product_dto.dart` style |
| 4 | `lib/data/repositories/firebase_banner_repository.dart` | Firestore impl on `/banners`; active stream = `where('isActive', isEqualTo: true)` ordered by `sortOrder` client-side (avoids a new composite index); try/catch → `Exception` like `firebase_product_repository.dart` |
| 5 | `lib/core/providers/banner_provider.dart` | `class BannerProvider with ChangeNotifier` — **default constructor** (registered as `BannerProvider()` in `main.dart:68`), optional `{BannerRepository? repository}` param defaulting to `FirebaseBannerRepository()` (matches `ProductProvider` pattern); exposes `streamActiveBanners()`, `streamAllBanners()`, and add/update/delete with `isLoading`/`errorMessage` state |

Firestore schema for `/banners/{id}`: `imageUrl` (Cloudinary URL), `category` (nullable — tap filters home grid), `isActive`, `sortOrder`, `createdAt`.

### 0.2 `lib/core/design/widgets/banner_carousel.dart`

Call site (`customer_home_screen.dart:142`): `BannerCarousel(onBannerTap: _selectCategory)` where `_selectCategory` is `void Function(String)`.

- Signature: `const BannerCarousel({super.key, required this.onBannerTap});` with `final void Function(String category) onBannerTap;`
- `StreamBuilder<List<BannerItem>>` on `context.read<BannerProvider>().streamActiveBanners()`; renders `SizedBox.shrink()` when empty/waiting/error (the call-site comment requires auto-hide).
- `PageView.builder` ~160 px tall, `cached_network_image`, rounded `AppTokens.rLg`, page-dot indicator, auto-advance `Timer` (dispose properly), tap → `onBannerTap(banner.category!)` only when category non-null.
- Use theme/`AppTokens` colors only (no hardcoded colors).

### 0.3 `lib/core/design/widgets/category_icon_rail.dart`

Call site (`customer_home_screen.dart:155-159`): `CategoryIconRail(categories: categories, selectedCategory: _selectedCategory, onSelect: _selectCategory)`.

- Signature: `const CategoryIconRail({super.key, required this.categories, required this.selectedCategory, required this.onSelect});` (`List<String>`, `String`, `void Function(String)`).
- Horizontal `ListView` of icon+label tiles; icon per known category name (map with a default `Icons.category_outlined` fallback since admin categories are free-text); selected tile highlighted with `scheme.primary`.

### 0.4 `lib/core/design/widgets/delivery_eta_badge.dart`

Call sites: `const DeliveryEtaBadge(style: DeliveryEtaBadgeStyle.chrome)` (`customer_home_screen.dart:239`, inside a `const` context — the constructor **must be const**) and `const DeliveryEtaBadge()` (`product_details_screen.dart:108`).

- `enum DeliveryEtaBadgeStyle { chrome, surface }` (default `surface`).
- `const DeliveryEtaBadge({super.key, this.style = DeliveryEtaBadgeStyle.surface});`
- Body: `StreamBuilder<AppConfig>` on `context.read<ConfigProvider>().streamAppConfig()`; hide (`SizedBox.shrink`) when `etaLabel` is null/empty (documented contract in `app_config.dart:6-8`); pill chip with ⚡/timer icon + label. `chrome` style uses `AppTokens` brand chrome-yellow (`app_tokens.dart:18`), `surface` uses `scheme.surfaceContainerHighest`.

### 0.5 `lib/modules/customer/screens/search_screen.dart`

Call site (`customer_home_screen.dart:122`): `const SearchScreen()` pushed via `MaterialPageRoute`. Home-screen comment (`:111-112`) promises "recent searches, debounced query".

- Const-constructible `StatefulWidget`, no params.
- Autofocused `TextField` in the app bar; 300 ms debounce `Timer`.
- Data: reuse `context.read<ProductProvider>().streamProducts()` and filter client-side on name/category/description (products are already streamed whole — no new index needed).
- Recent searches: `shared_preferences` string list (cap 10), chips shown when the query is empty, tap → run search, clear-all action.
- Results reuse `ProductCard` with the same cart wiring as the home grid (`customer_home_screen.dart:202-213`); `EmptyState` for no matches.

### 0.6 `lib/modules/admin/screens/banner_management_screen.dart`

Call site (`admin_profile_screen.dart:273`): `const BannerManagementScreen()`.

- Admin list of **all** banners (`streamAllBanners`) with active toggle, reorder (sortOrder ±), delete (confirm dialog), and an add/edit bottom sheet: image pick via `image_picker` → upload through `CloudinaryService` (Phase 2 moves signing server-side; call the same service either way), optional category dropdown fed from `config/app.categories` + `_kDefaultCategories`, isActive switch.
- Follow the existing sheet pattern from `admin_home_screen.dart` `_AddProductSheet`.

### 0.7 Verification gate (end of Phase 0)
- `flutter analyze` → **0 errors** (warnings triaged).
- `flutter test` passes.
- Manual run: customer home renders with 0 banners (carousel hidden), ETA badge hidden until `etaLabel` set, search + category rail functional; admin can create a banner and it appears on the customer home.

---

## Phase 1 — Runtime blockers (P0, ~0.5 day)

### 1.1 Missing composite index (breaks per-product ledger sheet)
`firestore.indexes.json` — add:
```json
{
  "collectionGroup": "inventoryLogs",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "productId", "order": "ASCENDING" },
    { "fieldPath": "timestamp", "order": "DESCENDING" }
  ]
}
```
Deploy with `firebase deploy --only firestore:indexes`. Required by `firebase_product_repository.dart:55-64`.

### 1.2 `config/dashboard_stats` fragility
All four triggers call `statsRef.update(...)` which **throws if the doc doesn't exist** (`functions/src/index.ts:381,392,479,545,587`). Change every `statsRef.update({...})` to `statsRef.set({...}, { merge: true })` — `FieldValue.increment` works identically under `set+merge` and self-heals a missing doc. Add a regression test (Phase 5.3).

### 1.3 Dead `AdminProfileScreen`
It's fully built (biometric toggle, banner-management link) but unreachable. Wire it as the admin's profile surface: in `admin_home_screen.dart`, replace the profile tab's `UserProfileScreen(isEmbedded: true)` usage (or add a 5th nav item) with `AdminProfileScreen`. This also resolves the "admin profile edits blocked by rules" issue for the avatar path, because `AdminProfileScreen` doesn't write to `/admins`. Decision point: if the team prefers the shared `UserProfileScreen` for admins, delete `AdminProfileScreen` instead — but then hide the edit/avatar actions for the admin role (writes are rules-blocked, see 2.3d).

---

## Phase 2 — Security hardening (P1, ~2–3 days, parallel with Phase 1)

### 2.1 Cloudinary secret leak (do first — it's in git history)
1. **Rotate the API secret in the Cloudinary console immediately** (manual step, before any code).
2. New callable in `functions/src/index.ts`: `getCloudinarySignature` — requires auth + active-admin check (same guard as `createRiderLogin`, `index.ts:626-630`); returns `{ timestamp, signature, apiKey, cloudName, folder }` computed with `crypto.createHash('sha1')` over `folder=...&timestamp=...` + secret. Secret supplied via `firebase functions:config`/secret manager (`defineSecret('CLOUDINARY_API_SECRET')`), never in source.
3. Rewrite `lib/core/services/cloudinary_service.dart`: delete `apiKey`/`apiSecret` constants; call the callable for the signature, then POST the multipart upload exactly as today. Keep the same `uploadImage(File) → String?` contract so all call sites (`admin_home_screen.dart`, `user_profile_screen.dart`, new banner screen) are untouched.
4. Customer avatars: customers aren't admins, so avatar upload needs either a second non-admin signature path (auth-only, `folder: 'avatars/{uid}'`) in the same callable, or moving avatars to Firebase Storage (rules already support a per-uid pattern — see 4.3). Pick one; recommend the callable variant to keep a single image pipeline.
5. Rename folder `testing-inventory` → `products` (config value, not code literal).

### 2.2 Remove the admin backdoor
Delete `firebase_auth_repository.dart:163-174` (the `admin@blinkbasket.com` fabricated model) **and** the email-query fallback at `:151-160` — doc-ID-must-equal-UID is the documented convention (`firestore.rules:6`) and the claim-sync trigger (`onAdminWritten`) only works keyed by UID. Document the bootstrap step ("create `admins/{uid}` in console") in README instead.

### 2.3 Reconcile client writes with Firestore rules
Each item is a deliberate product decision, implemented on whichever side is correct:

| Item | Decision | Change |
|---|---|---|
| a. Rider duty toggle (`delivery_home_screen.dart:127-135`) | Duty ≠ account-enabled. `isActive` currently drives **both** the admin enable/disable *and* the claim sync (`onRiderWritten` strips the `delivery` claim when false) — a rider toggling "off duty" would strip their own claim. | Introduce `onDuty: bool` on `deliveryBoys`. Rules: extend the self-update allowlist to `hasOnly(['uid','fcmTokens','onDuty'])` (`firestore.rules:61`). Client: toggle writes `onDuty`; `streamDeliveryBoys()` (assignment sheet, `firebase_order_repository.dart:60-71`) filters `isActive == true` **and** `onDuty == true` client-side. `isActive` stays admin-only. |
| b. Rider profile edit (`ProfileProvider` full-doc `set()`) | Riders may edit avatar + vehicle details only; identity fields stay admin-controlled. | Replace the full `set()` path for role=`delivery` with a field-scoped `update()` of `{avatarUrl, vehicleDetails}`; extend the rules allowlist accordingly (`['uid','fcmTokens','onDuty','avatarUrl','vehicleDetails']`). |
| c. Customer `updateActiveStatus` (`profile_provider.dart:222-246`) | Self-deactivation isn't a real feature; rules already forbid it. | Delete the method and any UI switch bound to it. |
| d. Admin profile edit via `updateUserProfile` → `/admins` | Admin display data is console-managed; `write: false` stays. | With 1.3 (AdminProfileScreen) admins no longer hit this path; additionally guard `ProfileProvider.updateProfileDetails` to no-op with a clear error for role=`admin`. |
| e. Legacy `saveDeliveryBoyUid` migration (`firebase_auth_repository.dart:184-197`) | All riders are provisioned by `createRiderLogin` (docId == uid); the copy-doc+delete path violates rules and can never succeed. | Delete the method + the `model.uid.isEmpty` branch in `auth_provider.dart:294-296`; treat a whitelist doc without matching UID as "Contact admin". |
| f. `AuthProvider` duplicate address CRUD (`auth_provider.dart:195-225`) | `ProfileProvider` owns addresses. | Delete the three duplicated methods. |

Update `functions/test/firestore.rules.test.ts` for the new allowlist (rider can change `onDuty`/`avatarUrl`/`vehicleDetails`; still cannot touch `isActive`, `village`, `email`).

### 2.4 Android release readiness
- `android/app/build.gradle.kts`: set final `applicationId` (e.g. `com.blinkbasket.app`), create upload keystore + `key.properties` (git-ignored), replace the debug `signingConfig` (`:36-42`).
- Register the release SHA-1/SHA-256 in Firebase console (Google Sign-In breaks without it); re-download `google-services.json`.
- Version bump strategy in `pubspec.yaml`.

---

## Phase 3 — Functionality completion (P2, ~1–2 weeks)

### 3.1 Prescription flow (finish it — flag + copy already ship)
Currently `requiresPrescription` reaches the cart banner (`cart_screen.dart:184,321`) but nothing is ever uploaded and nothing blocks dispatch. `storage.rules:16-24` already provisions `/prescriptions/{uid}` (image/pdf ≤ 5 MB, owner-write, admin-read).
1. Add `firebase_storage` dependency.
2. Cart: when any line has `requiresPrescription`, require an upload before checkout — picker (camera/gallery/pdf) → `prescriptions/{uid}/{orderTimestamp}.<ext>` → pass `prescriptionUrl` into `placeOrder` payload.
3. `placeOrder` CF: if any resolved product has `requiresPrescription == true` and no `prescriptionUrl` string was sent, reject `failed-precondition`; store `prescriptionUrl` + `prescriptionStatus: 'pending_review'` on the order.
4. Admin order queue: show a "Rx" badge; view attachment; approve/reject before rider assignment (rules: admin already has full update rights).
5. Emulator tests: rejection without URL, acceptance with URL.
*(Fallback if descoped: hide the admin toggle + customer messaging behind a feature flag so shipped UI matches behavior.)*

### 3.2 Stale-order expiry (stock is reserved forever today)
New scheduled function in `functions/src/index.ts`:
```ts
export const expireStaleOrders = onSchedule({ region: REGION, schedule: "every 30 minutes" }, ...)
```
Query `orders` where `status == 'pending'` and `createdAt < now − EXPIRY_HOURS` (new composite index `orders(status, createdAt)`), set `status: 'cancelled'`, `cancelReason: 'auto_expired'`. The existing `onOrderWritten` cancellation branch (`index.ts:407-448`) already releases the reservation and writes the `return` ledger entry — no duplication. Make `EXPIRY_HOURS` a `config/app` field editable from Store Settings.

### 3.3 Notification deep-linking (payload already carries `orderId`)
In `main.dart`: handle `FirebaseMessaging.instance.getInitialMessage()` (cold start) and `onMessageOpenedApp` (background tap). Add a `navigatorKey` to `MaterialApp` (`app.dart`), then route by role: customer → `OrderTrackingScreen(orderId)`, rider → fetch order and push `TaskDetailScreen`. Foreground SnackBar (`main.dart:37-47`) gains an "View" action doing the same.

### 3.4 Inventory-ledger taxonomy unification
Single source of truth `lib/domain/entities/inventory_ledger.dart`: define the enum-like constants `restock | sale | return | correction | reserve | release`. Fixes:
- `placeOrder` reservation entry: `changeType: 'reserve'`, and rename the misleading `adminId: uid` → keep field but write `actorId` semantics: `adminId: 'system'`, add `customerId: uid` (`index.ts:199-208`).
- Cancellation entry keeps `return`; OTP delivery keeps `sale` (rider uid ok, note in `notes`).
- `inventory_logs_screen.dart:14-42`: replace the icon/color maps' phantom types (`release`, `cancel_release`, `stock_update`) with the real vocabulary.
- Admin adjust sheet (`admin_home_screen.dart:2860`): constrain `_changeType` to `restock | correction | return`.

### 3.5 Cart persistence
`CartProvider` (`lib/core/providers/cart_provider.dart`) is in-memory. Persist `{productId: qty}` to `shared_preferences` on every mutation; on app start, rehydrate against live products (reuse `ReorderHelper`'s stock-capping logic in `reorder_helper.dart:19-40`). Clear on `clearCart()` and logout.

### 3.6 Admin console decomposition (quality gate for everything above)
Split `admin_home_screen.dart` (3,568 lines) into:
```
lib/modules/admin/screens/  admin_home_screen.dart (shell + nav + biometric lock only)
                            tabs/dashboard_tab.dart, orders_tab.dart, inventory_tab.dart, riders_tab.dart
lib/modules/admin/widgets/  assign_rider_sheet.dart, add_product_sheet.dart, edit_rider_sheet.dart,
                            product_ledger_sheet.dart, metric_card.dart
```
Move `_hasActiveDeliveries` rider-deletion guard (`:1857`) into `OrderProvider`/use case. Pure refactor — no behavior change; do it before Phase 3 features land in these files, not after.

### 3.7 Dead-code removal
Delete: `SeederService` (`lib/core/services/seeder_service.dart` — or move to a `tool/` dev script), the Node-backend branch (`http_order_repository.dart` + `backend_config.dart`, re-point `main.dart:63` to `FirebaseOrderRepository()`), and whichever of `AdminProfileScreen`/`UserProfileScreen`-for-admin lost the 1.3 decision.

### 3.8 UI consistency pass
- Replace hardcoded `Colors.white / grey.shade50 / Colors.green` with `scheme`/`AppTokens` across: `earnings_screen.dart:43-64`, `task_detail_screen.dart:110-117`, `rider_map_screen.dart:56-71`, `address_book_screen.dart:27-35`, `route_generator.dart` splash (`:88-111`), `delivery_home_screen.dart` (several) — makes dark mode coherent.
- Register the directly-pushed screens (`OrderTracking`, `Search`, `AddRider`) as named routes in `route_generator.dart` for consistency (optional, low priority).

---

## Phase 4 — Integrations (P2, ~2–3 days, parallel with Phase 3)

| # | Work | Detail |
|---|---|---|
| 4.1 | **Crashlytics + Analytics** | Add `firebase_crashlytics` (+ `firebase_analytics`); hook `FlutterError.onError`/`PlatformDispatcher.onError` in `main.dart`; log key funnel events (login, add_to_cart, place_order, delivered). Without this there is zero production observability. |
| 4.2 | **Cloudinary server-signed** | Done in 2.1 (listed here for tracking — it is the integration change). |
| 4.3 | **Firebase Storage decision** | If 3.1 ships, Storage becomes live for prescriptions — keep `storage.rules` and delete the unused `/products` block (product images stay on Cloudinary). If 3.1 is descoped, delete `storage.rules` prescriptions block too so deployed rules match reality. |
| 4.4 | **OSM tile policy** | `flutter_map` screens must set a proper user-agent + visible attribution per OSM policy; evaluate a commercial tile provider if traffic grows. Files: `rider_map_screen.dart`, `leaflet_location_picker.dart`. |
| 4.5 | **FCM hygiene** | Prune stale tokens: on `messaging/registration-token-not-registered` errors in `sendPushToTokens` (`index.ts:71-87`), remove the failing token from the user doc (response contains per-token results). |
| 4.6 | **Google Sign-In release config** | SHA registration from 2.4; verify on a release build. |

---

## Phase 5 — Testing & CI (continuous from Phase 0)

### 5.1 Make the client testable (small DI refactor)
`AuthProvider` hard-news `FirebaseAuthRepository` (`auth_provider.dart:24`); `ProfileProvider` likewise. Add optional constructor injection (same pattern `OrderProvider` already uses). No behavior change; unlocks everything below.

### 5.2 Flutter tests (highest-value first)
| Test | Target |
|---|---|
| `AuthProvider` role verification | mock `AuthRepository`: customer needs-profile-setup path, inactive-account rejection, rider whitelist mismatch, admin missing-doc rejection (`auth_provider.dart:252-342`) |
| Cart math | totals, increment/decrement/remove, `addItemQuantity`, persistence rehydration (3.5) |
| `ReorderHelper` | skip-missing, cap-at-stock |
| New Phase-0 widgets | `BannerCarousel` hides when empty; `DeliveryEtaBadge` hides without label; `SearchScreen` debounce filters; `CategoryIconRail` selection |
| Checkout widget test | `CartScreen` with mocked providers: validation, address fallback chain (`cart_screen.dart:109-124`), success navigation |

### 5.3 Cloud Functions tests (extend existing suite)
- `createRiderLogin`: non-admin rejected, dup email, doc+claims created.
- Stats triggers with **missing** `config/dashboard_stats` (regression for 1.2).
- `expireStaleOrders` (3.2): expires only old pending, releases stock.
- Prescription gating (3.1).
- Rules: new `deliveryBoys` allowlist (2.3a/b) — positive + negative.

### 5.4 CI (`.github/workflows/ci.yml`)
- Add `flutter build apk --debug` job (catches Gradle/manifest breakage analyze can't).
- Add `dart format --output=none --set-exit-if-changed .` (or `flutter analyze --fatal-infos` once clean).
- Optional nightly: `integration_test/` smoke against emulators (login→browse→cart) via `flutter drive` on an Android emulator runner.

### 5.5 Documentation debt
- Fix the CLAUDE.md contradiction: the "Quick Commerce Guidelines" block mandates Riverpod/Freezed/Either while the codebase is Provider/manual-DTO/Result — rewrite that section to match reality (or schedule a real migration; recommend: match reality now).
- README bootstrap runbook: Firebase project setup, first-admin console step, `config/app` + `config/dashboard_stats` seeding, emulator workflow, Cloudinary secret config.

---

## Acceptance summary (definition of done per phase)

| Phase | Done when |
|---|---|
| 0 | `flutter analyze` 0 errors; app runs on device; banner CRUD round-trip works; CI green |
| 1 | Ledger sheet opens without index error on fresh project; stats survive missing doc; admin profile reachable |
| 2 | No secret material in `lib/`; backdoor removed; every UI write succeeds against deployed rules (manually exercised per role); release APK signed + Google Sign-In works on it |
| 3 | Rx-gated checkout enforced server-side; stale pending orders auto-cancel with stock release; notification tap opens the right screen; ledger UI shows correct icons for all real entries; cart survives restart; `admin_home_screen.dart` < 400 lines |
| 4 | Crash visible in Crashlytics from a test crash; token pruning verified in emulator; OSM attribution visible |
| 5 | CI runs analyze + tests + apk build; Functions suite ≥ current 45 tests + new coverage; provider tests cover auth role flows |

**Suggested milestone cut for a pilot release:** Phases 0–2 complete + 3.2 (order expiry) + 3.3 (deep links) + 4.1 (Crashlytics). Everything else can follow the pilot.
