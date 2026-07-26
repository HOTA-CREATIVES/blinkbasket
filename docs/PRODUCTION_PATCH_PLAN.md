# JP Mart (J C Mart) — Production Patch Plan
*Veeravasaram-locked, COD-only, Flutter + Firebase. Builds on `CODEBASE_ANALYSIS.md` and `IMPLEMENTATION_PLAN.md` — cited, not repeated. New here: constraint verification, Firebase cost optimization, user stories, BoE.*

**Freshness note**: `CODEBASE_ANALYSIS.md`'s headline "app does not compile" finding is **stale** — re-verified this session, `flutter analyze` returns 0 issues and all previously-"missing" banner/search files exist and are fully built. Every other gap below (security, rules mismatches, missing index, dead code) was independently re-confirmed against current files this session and is still live.

## 1. Constraint verification

| Constraint | Current implementation | Verdict |
|---|---|---|
| Service area locked to Veeravasaram + nearby villages | `placeOrder` rejects orders >12km from village centroids (Veeravasaram/Rayakuduru/Srungavruksham/Mentada), `functions/src/index.ts:118-125` | ⚠️ **Leaky** — check is **skipped** if client omits `latitude`/`longitude` (`index.ts:118`); an out-of-zone order with no coords is silently accepted. **Fix**: reject `invalid-argument` when coords are missing, before the radius check. |
| COD-only, no payment gateway | No payment SDK anywhere; `paymentMethod: "COD"` hardcoded on every order | ✅ By design, no gap |
| Flutter + Firebase stack | Provider state mgmt, Firebase Auth/Firestore/Functions(`asia-south1`)/FCM, Cloudinary images | ✅ Confirmed |

## 2. Gap table
*(condensed from `CODEBASE_ANALYSIS.md` §12; file:line citations point there)*

| # | Gap | Severity | Effort | Ref |
|---|---|---|---|---|
| ~~1~~ | ~~6 missing files break compile (banner/search/ETA feature)~~ — **verified resolved**: all 6 files now exist and are fully built; `flutter analyze` returns **0 issues** (re-run this session). `CODEBASE_ANALYSIS.md` §1 is stale on this point. | ✅ Closed | — | re-verified this session |
| 2 | Missing composite index `inventoryLogs(productId,timestamp)` | 🔴 Blocker | 0.25d | §4.3 — **re-confirmed live**: no such entry in `firestore.indexes.json` |
| 3 | `config/dashboard_stats` triggers use `.update()`, throw if doc missing | 🔴 Blocker | 0.25d | §3.1 — **re-confirmed live** (`functions/src/index.ts:381,392,479,545,587` all still `.update()`) |
| 4 | Cloudinary API secret hardcoded client-side (leaked to git history) | 🔴 Critical security | 1d | §5 — **re-confirmed live** |
| 5 | Hardcoded admin backdoor account (`admin@blinkbasket.com`) | 🔴 Critical security | 0.5d | §3.3 — **re-confirmed live** (`firebase_auth_repository.dart:163`) |
| 6 | Rider duty toggle / rider & admin profile edits silently rules-denied | 🟠 High | 1.5d | §3.4 — **re-confirmed live** (`firestore.rules:51-64` still `hasOnly(['uid','fcmTokens'])`, no `onDuty` field) |
| 7 | Android release signed with debug keys, placeholder applicationId | 🟠 High (release-blocking) | 0.5d | §1 — **re-confirmed live** (`build.gradle.kts:27,40`) |
| 8 | Geofence accepts orders with missing coordinates | 🟠 High | 0.25d | this doc §1 |
| 9 | No order-expiry job — stale `pending` orders reserve stock forever | 🟡 Medium | 1d | §12 P2 |
| 10 | Prescription flow: flag + UI messaging only, no upload/enforcement | 🟡 Medium | 3d | §1, §3 |
| 11 | Notification tap doesn't deep-link to order | 🟡 Medium | 0.5d | §12 P2 |
| 12 | `admin_home_screen.dart` god-file (3,568 lines) | 🟡 Medium (maintainability) | 3d | §10 |
| 13 | Ledger `changeType` vocabulary drift (writers vs. display map) | 🟢 Low | 0.5d | §3.5 |
| 14 | Dead code: `AdminProfileScreen`, `SeederService`, Node-backend branch | 🟢 Low | 0.5d | §3.5 |
| 15 | Test debt: Flutter provider/UI coverage ~15-25%, no E2E | 🟡 Medium | 5d | §6 |
| 16 | No Firebase App Check — cost/abuse exposure | 🟠 High (cost risk) | 1d | this doc §3 |
| 17 | Unbounded admin streams (`streamAllOrders`, ledger, riders) | 🟡 Medium (cost risk) | 1d | this doc §3 |
| 18 | Firestore triggers fire on every write, no diff-guard | 🟢 Low (cost risk) | 1d | this doc §3 |
| 19 | No retention/TTL policy on `inventoryLogs` | 🟢 Low (cost risk) | 0.25d | this doc §3 |

## 3. Firebase changes — cost optimization
*(new value-add of this task; not covered in prior docs)*

| Area | Current state | Cost risk | Recommended change |
|---|---|---|---|
| Functions scaling | No `minInstances` set anywhere (verified in `index.ts`) | None | ✅ **Pass** — already scale-to-zero, no idle billing |
| Trigger over-firing | `onOrderWritten`/`onProductWritten`/`onRiderWritten`/`onAdminWritten` run on *every* field write | Low-med | Add `before`/`after` field-diff short-circuit at top of each trigger — skip no-op writes (e.g. editing a description shouldn't re-run stock/stat logic) |
| Unbounded admin reads | `streamAllOrders`, ledger, `streamAllDeliveryBoys` pull whole collections, no `.limit()` | Med, grows with history | Add `.limit()` + date-range filters before order volume scales past pilot |
| App Check | Not configured | Med-high (bot/abuse traffic can spike bill on callables + Firestore) | Add Play Integrity (Android) / DeviceCheck (iOS) App Check on Functions + Firestore |
| Image hosting | Product images on Cloudinary (not Firebase Storage) | None | ✅ **Pass** — offloads Storage egress cost |
| Offline persistence | Enabled client-side (`main.dart`) | None | ✅ **Pass** — reduces redundant reads |
| Data retention | No TTL policy; `inventoryLogs` grows unbounded | Low, compounds over years | Add native Firestore TTL policy on `inventoryLogs.timestamp` (e.g. 18-month retention) — zero function cost |
| Budget alerting | Not verifiable from repo (console-level setting) | Unknown | Ops action: set a GCP budget alert at $10–25/month given expected village-scale usage |
| Region | All Functions in `asia-south1` | None | ✅ **Pass** — matches SRS latency requirement, avoids cross-region egress |

## 4. Features × screens × backend
*(condensed from `CODEBASE_ANALYSIS.md` §2.1 — status flags only, see that doc for detail)*

| Persona | Screens | Firestore / CF touchpoints | Status |
|---|---|---|---|
| Customer | Login, profile setup, home, search, product details, cart, order success/history/tracking, address book | `products`, `config/app`, `orders`, `users`, `placeOrder` CF | ✅ All present and compiling (`flutter analyze`: 0 issues, re-verified this session) |
| Delivery | Home (tasks/map/earnings/profile), task detail | `orders` (by `deliveryBoyId`), `verifyDeliveryOtp` CF | ⚠️ Duty toggle + profile edit rules-denied; rest ✅ |
| Admin | Dashboard, orders, inventory + ledger, riders, store settings, banner mgmt, profile | `config/dashboard_stats`, `products`, `orders`, `deliveryBoys`, `inventoryLogs`, `createRiderLogin` CF | ⚠️ Banner mgmt screen exists and compiles ✅; `AdminProfileScreen` still has no caller anywhere in `lib/` — dead/unreachable (re-confirmed) |

## 5. User flows
*(reused verbatim from `CODEBASE_ANALYSIS.md` §2.5)*

1. **Customer**: login → (register → profile setup) → home → product details/cart → address (saved/map-pin/village fallback) → `placeOrder` → success (OTP shown) → track → delivered → rate.
2. **Rider**: whitelisted login (UID locks on first login) → task list → task detail (checklist → swipe pickup/out-for-delivery → OTP entry) → `verifyDeliveryOtp` → earnings.
3. **Admin**: login → biometric gate → dashboard → orders queue → assign rider → inventory (CRUD, stock adjust + ledger) → riders (create/edit/soft-delete) → store settings.

## 6. User stories
*(new — mapped to highest-severity gaps only; already-working features are not restated)*

1. ~~As a **developer**, I want the 6 missing banner/search/ETA files created...~~ — **already done**; `flutter analyze` is clean, no action needed.
2. As a **customer**, I want my order rejected if my device can't provide GPS coordinates, so that out-of-zone orders can't slip past the Veeravasaram geofence (gap #8).
3. As the **business owner**, I want the Cloudinary API secret rotated and moved server-side, so that the image pipeline can't be hijacked (gap #4).
4. As a **security-conscious operator**, I want the hardcoded admin backdoor account removed, so that no one can self-provision admin UI access (gap #5).
5. As a **rider**, I want my duty toggle and profile edits to actually persist, so that going off-duty doesn't strip my delivery claim or silently fail (gap #6).
6. As an **admin**, I want stale pending orders to auto-expire and release reserved stock, so that abandoned carts don't lock inventory indefinitely (gap #9).
7. As a **customer**, I want tapping an order-status push notification to open that order's tracking screen, so that I don't have to hunt for it manually (gap #11).
8. As the **business owner**, I want Firebase App Check enabled, so that bot/abusive traffic can't spike the Firestore/Functions bill (gap #16).
9. As an **admin**, I want order/ledger history views paginated, so that the console stays fast and read-cost stays flat as order history grows (gap #17).
10. As the **business owner**, I want a retention policy on inventory logs, so that storage cost doesn't grow unbounded over years of operation (gap #19).

## 7. BoE Estimation

### Engineering effort
*(day-rate assumption: ₹4,000–6,000/day, mid-level Flutter+Firebase contractor, India market — replace with your actual rate)*

| Phase | Scope | Days |
|---|---|---|
| ~~0~~ | ~~Restore compilation~~ — **already resolved**, verified via `flutter analyze` (0 issues) this session | 0 |
| 1 | Runtime blockers (composite index, stats-doc `.set(merge)` fix, wire up `AdminProfileScreen`) | 0.5 |
| 2 | Security hardening (rotate + server-side Cloudinary signing, remove admin backdoor, fix rider/admin rules mismatches) | 2.5 |
| 2b | Geofence mandatory-coords fix (new, bundled into Phase 2) | 0.25 |
| 3 | Functionality completion (prescription upload, order expiry, notif deep-link, admin console decomposition) | 10.0 |
| 4 | Integrations (Crashlytics, OSM attribution, FCM token hygiene) | 2.5 |
| 4b | App Check + Firestore TTL policy (new) | 1.25 |
| 4c | Trigger diff-guards + admin stream pagination (new) | 2.0 |
| 5 | Testing & CI (initial investment; ongoing beyond this) | 5.0 |
| **Total** | | **~24.0 days** |

**Cost range**: 24 days × ₹4,000–6,000/day = **₹96,000 – ₹1,44,000** (~US $1,150–$1,750).

### Monthly Firebase run cost (pilot/village scale)
*Assumptions: ~100 orders/day (~3,000/month), ~500 SKUs, single region `asia-south1`, no `minInstances`. Adjust if actual volume differs.*

| Service | Estimated monthly usage | Blaze cost |
|---|---|---|
| Firestore reads | ~250k–350k | ~$0.15–0.20 |
| Firestore writes | ~55k–75k | ~$0.10–0.14 |
| Firestore storage | <1 GB | ~$0.15–0.20 |
| Cloud Functions invocations | ~20k–40k | $0 (well under 2M free tier) |
| Cloud Functions GB-sec/CPU-sec | low | $0 (under free tier) |
| Cloud Storage (prescriptions only) | negligible | ~$0 |
| Firebase Auth | <500 MAU | $0 (free to 50k MAU) |
| FCM | — | $0 (always free) |
| Cloudinary (non-Firebase) | within free tier at this image volume | $0, monitor if catalog grows |
| **Total estimated** | | **≈ $0–5/month** |

At this scale the app should run at or near Firebase's free tier; cost only becomes material if order volume grows an order of magnitude or App Check is skipped and abusive traffic hits the callables.

## 8. Milestone recommendation
Keep `IMPLEMENTATION_PLAN.md`'s pilot cut (Phases 0–2 + 3.2 order-expiry + 3.3 deep-links + 4.1 Crashlytics); slot the geofence mandatory-coords fix into Phase 2, and App Check + TTL policy into Phase 4 — no separate release train needed for the cost items.
