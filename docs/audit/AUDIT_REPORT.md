# Audit Report — J C Mart (hypermart)

**Audit date:** 2026-09-29 · **Auditor:** Buffy (Codebuff) · **Mode:** read-only analysis; no source/config/dependency changes; existing docs left in place per user instruction.

---

## 1. Executive summary

J C Mart is a **Flutter + Firebase hyperlocal grocery app** (COD-only, rider-broadcast dispatch, three personas) that is **functionally near-complete and substantially hardened since its last internal audit (2026-07-18)**. Every critical finding from the previous audits has been verifiably fixed in the current working tree:

- Cloudinary secret now lives in Secret Manager; uploads use admin-only signed uploads ([index.ts:1169](../../functions/src/index.ts#L1169)).
- The `admin@blinkbasket.com` backdoor is gone; riders can no longer self-migrate UIDs.
- App Check is enforced on all sensitive callables; per-UID rate limiting added; Crashlytics/Analytics wired; order expiry + broadcast escalation implemented; missing composite indexes added; rules/client write mismatches resolved (rider self-edit allowlist, duty toggle); god-file halved (3,568 → 1,985 lines); notification deep-links added.

**The top risks are now operational and consistency risks, not classic vulnerabilities:**

1. The Android **release identity is still `com.example.hypermart`** — Play-rejected, and irreversible once published.
2. **Cross-actor schema drift**: Cloud Functions write ledger actor as `adminId`, the client writes `actorId` — the audit trail is split-keyed (bridged only in the Dart DTO).
3. The **CI deploy workflow deploys nothing** (Hosting action, no hosting config; functions deploy is manual only).
4. **Documentation is badly stale** — 16 legacy docs contradict current code (including security-audit docs claiming live issues that are fixed), which is itself an operational risk.
5. **Flutter-side test coverage is models-only**; no provider/use-case/widget tests; the rules "test suite" mirrors rules logic rather than executing the rules file; E2E is outside CI.

Security posture of the server rules and functions is **strong** (transactional stock, server-authoritative pricing, field allowlists, OTP privacy, deny-all catch-all). Production readiness is gated on release-identity/ops items, not on security rework.

## 2. Scope and method

- **In scope:** all first-party code (`lib/`, `functions/`, `test/`, `functions/test/`, `tests/`), Firestore/Storage rules and indexes, CI/CD workflows, Firebase config, Android build config, tooling configs, and all 16 existing docs.
- **Out of scope:** runtime behavior (nothing was executed), Play/Firebase console settings, git history forensics (secret-rotation verification), binary/keystore contents.
- **Method:** full read of rules/indexes/workflows/configs; complete read of `functions/src/index.ts` (1,293 lines); targeted reads of all security-critical and representative client files; code-search sweeps for secrets, TODOs, dead code, layering violations; cross-checking every prior-doc claim against current code. **Everything is evidence-cited; unverifiable items are marked "Needs verification."**

## 3. System overview

See [../context/ARCHITECTURE.md](../context/ARCHITECTURE.md) (diagrams), [../context/DATA_MODEL.md](../context/DATA_MODEL.md) (schemas), [../context/API_CONTRACTS.md](../context/API_CONTRACTS.md) (function surface). In brief: Flutter client → Provider → use cases → repository interfaces → Firebase implementations; 13 Cloud Functions (9 callable, 4 triggers, 2 scheduled share the count) in `asia-south1`; security split between client-evaluated Firestore rules and server-authoritative functions; FCM broadcast dispatch with 90 s escalation and 24 h auto-expiry.

## 4. Findings table

Severity: Critical / High / Medium / Low / Info. Effort: S (<0.5d) / M (0.5–2d) / L (>2d). Confidence: Verified (cited evidence) / Needs verification.

| ID | Sev | Category | Title | Evidence | Impact | Recommendation | Effort | Confidence |
|---|---|---|---|---|---|---|---|---|
| H-1 | High | Data integrity | Ledger actor key drift: functions write `adminId`, client writes `actorId` | [index.ts:365](../../functions/src/index.ts#L365) vs [inventory_ledger_dto.dart:38](../../lib/data/models/inventory_ledger_dto.dart#L38) (DTO reads `actorId ?? adminId`) | Audit trail split-keyed; any new reader (exports, BI, admin UI) that filters one key silently loses half the entries; only the Dart DTO bridges both | Standardize on `actorId`+`actorType` everywhere; migrate writers in one commit; backfill is optional (DTO reads both) | S | Verified |
| M-1 | Medium | Maintainability | `admin_home_screen.dart` god-file (1,985 lines) despite partial decomposition | `wc -l` = 1,985; widgets already extracted to `screens/widgets/` | Slow review, merge conflicts, untestable business flows in UI | Continue extraction: order queue, inventory sheets, rider management as separate widgets + move flows into providers | M | Verified |
| M-2 | Medium | Release ops | Android identity still `com.example.hypermart`; release falls back to debug signing without keystore | [build.gradle.kts:24,39,50-58](../../android/app/build.gradle.kts#L39) | Play rejects `com.example.*`; a debug-signed "release" could be built and shipped accidentally | Decide final applicationId **now** (irreversible after publish); register Firebase Android app under it; make release build fail if key.properties is missing | S | Verified |
| M-3 | Medium | Quality | No Flutter provider/use-case/widget tests; model tests only | `test/` tree = 8 model/DTO/entity files; deleted legacy tests in working tree | Regressions in auth/checkout/cart logic ship undetected; CI stays green while breaking | Add AuthProvider role-discovery tests, placeOrder client-path tests, checkout widget tests; target providers first | L | Verified |
| M-4 | Medium | DevOps | Deploy workflow is a no-op: Hosting action with no hosting config; functions never deployed by CI | [deploy.yml](../../.github/workflows/deploy.yml) vs `firebase.json` (no `hosting` key) | False sense of automation; prod drifts until someone runs `firebase deploy --only functions` manually | Replace with `w9jds/firebase-action` (or firebase-tools) deploying `functions` (+ rules/indexes); add hosting only if web hosting is wanted | S | Verified |
| M-5 | Medium | Cost/ops | Unbounded collections: `inventoryLogs` and `supportTickets/messages` have no TTL/retention | rules show no TTL; `firestore.indexes.json` has no TTL field overrides | Storage cost and query latency grow forever; ledger `limit(200)` queries degrade | Add Firestore TTL policy on `inventoryLogs.timestamp` (e.g. 18 mo) and decide message retention | S | Verified |
| M-6 | Medium | Documentation | CLAUDE.md contradicts the code (Riverpod/Freezed/Either mandated; Provider/DTO/exceptions used) | [CLAUDE.md](../../CLAUDE.md) "Quick Commerce Guidelines" vs [pubspec.yaml](../../pubspec.yaml) | Agents/new devs follow wrong conventions; AI tooling actively misled | Rewrite the section to match reality (or adopt Riverpod deliberately — much bigger change) | S | Verified |
| M-7 | Medium | Documentation | 16 legacy docs contradict current code, including security docs claiming fixed issues are live | e.g. `CODEBASE_ANALYSIS.md` §5 "no crash reporting/App Check" vs [main.dart](../../lib/main.dart); `business_logic_security_audit.md` #1 "no floor guard" vs [firebase_product_repository.dart:123](../../lib/data/repositories/firebase_product_repository.dart#L123) | Dangerous: an operator "fixing" the audit may re-introduce churn or distrust real findings | Archive legacy docs under `docs/legacy/` (or delete); this audit's `docs/context/` replaces them | S | Verified |
| L-1 | Low | Privacy | `products` readable by unauthenticated users (`allow read: if true`) | [firestore.rules:94](../../firestore.rules#L94) | Catalog + margins (price/discount fields) exposed without auth; probably intentional for pre-login browsing | If pre-login browse isn't a requirement, change to `signedIn()`; if it is, document the decision | S | Verified |
| L-2 | Low | Compliance | No LICENSE file; root package.json says ISC while docs reference MIT | `ls LICENSE` → none; [package.json:30](../../package.json#L30) | Ambiguous rights for any third-party contributor | Add the intended LICENSE; align package.json license field | S | Verified |
| L-3 | Low | Reliability | In-memory rate limiter: per-instance, resets on cold start, unbounded Map growth per long-lived instance | [index.ts:28-46](../../functions/src/index.ts#L28-L46) | Effective limit is N× intended under autoscaling; periodic resets create gaps; map grows with unique UIDs | Accept for launch (document it); consider Firestore/Redis counter or App Check-only posture later | S | Verified |
| L-4 | Low | Consistency | `AdminProfileScreen` is routed but no in-app navigation reaches it (dead menu entry) | Only caller: [route_generator.dart:164](../../lib/core/utils/route_generator.dart#L164) | Dead surface; confused maintenance | Wire it into the admin UI or delete it | S | Verified |
| L-5 | Low | Hygiene | Four overlapping seed entry points | `scripts/seed.js`, `functions/seed.js`, `functions/seed_admin.js`, `lib/seed_main.dart` | Divergent demo data; onboarding confusion | Keep one (recommend `scripts/seed.js` + emulators), delete the rest | S | Verified |
| L-6 | Low | Hygiene | Firestore debug logs committed-adjacent (`firestore-debug.log`, `functions/firestore-debug.log`) | 0-byte files at repo root; `*.log` IS git-ignored ([.gitignore:3](../../.gitignore#L3)) | None — local clutter only | Delete locally; no action needed (already ignored) | S | Verified |
| I-1 | Info | Docs | README links to 12 docs by `file:///c:/Users/gurun/...` absolute paths | [README.md](../../README.md) | Links dead for everyone except one machine | Rewrite README links to relative repo paths; reconcile with the new `docs/context/` | S | Verified |
| I-2 | Info | Architecture | Dead Node-backend branch: `HttpOrderRepository` + `BackendConfig` target localhost:3000; no server exists | [backend_config.dart](../../lib/core/services/backend_config.dart) `useNodeBackend=false` | Confuses architecture docs; code exercised by nothing | Delete branch or commit the server; document the choice in ARCHITECTURE.md | S | Verified |
| I-3 | Info | Reliability | `createRiderLogin` returns the generated password in the callable response; admin hands it over manually | [index.ts:1127](../../functions/src/index.ts#L1127), [add_rider_screen.dart:154](../../lib/modules/admin/screens/add_rider_screen.dart#L154) | Password transits admin's device UI/clipboard; acceptable for village-scale ops | Consider a rider self-service reset via email later; document current process | S | Verified |
| I-4 | Info | Performance | No pagination on large streams (`streamAllOrders(limit:300)`, ledger `limit(200)`, riders `limit(200)`) | [firebase_order_repository.dart:50](../../lib/data/repositories/firebase_order_repository.dart#L50) | Fixed caps bound cost today but will silently truncate history as volume grows | Add date-range cursoring when order count approaches caps | M | Verified |
| I-5 | Info | Testing | `@firebase/rules-unit-testing` is a devDependency but no test executes the real rules file | [jest.setup.js](../../functions/test/jest.setup.js) mocks admin; rules tests mirror logic | Rules regressions pass CI | Add true emulator-based rules tests for the order status machine (Needs verification: no import found; confirm) | M | Verified (absence) |
| I-6 | Info | Config | CI pins Flutter 3.27.x while local dev uses any SDK; `typescript ^7.0.2` devDep at root vs ^5.6 in functions | [ci.yml:17](../../.github/workflows/ci.yml#L17), [package.json](../../package.json) | Version drift between dev and CI | Document required SDK; verify TS7 intent | S | Verified |

**Historical findings now VERIFIED FIXED (evidence):** Cloudinary secret server-side ([index.ts:1169-1206](../../functions/src/index.ts#L1169)); admin backdoor removed (repo-wide search clean); App Check on callables (every `onCall`); Crashlytics/Analytics ([main.dart](../../lib/main.dart)); order expiry (`expireStaleOrders`, :1256); broadcast escalation + batch optimization (:1209); missing composite index added (`firestore.indexes.json` includes `inventoryLogs(productId,timestamp)`); FCM dead-token pruning (index.ts:87-145); trigger diff-guards + `set(merge)` (onOrderWritten/onRiderWritten/onProductWritten/onAdminWritten); geofence requires coords (index.ts:274-281); `adjustStock` floor guard (:123-124); rider duty-toggle/profile-edit rules allowlist ([firestore.rules:56-66](../../firestore.rules#L56-L66)); OTP reveal biometric gate; support module added; banner module completed.

## 5. Positive observations

- **Server-authoritative core done right:** every rupee and every unit of stock is computed and moved server-side inside transactions; the client's cart is explicitly a preview.
- **Defense in depth:** App Check + per-UID rate limits + claim re-verification against live docs (`acceptOrder` re-reads the rider doc rather than trusting a stale JWT).
- **The rules file is genuinely good:** field allowlists, immutable role/isActive, write-once rating, one-step status transitions, OTP subcollection privacy, deny-all catch-all — each rule documents its intent.
- **Operational resilience thinking:** trigger-replay guard (`stockReleased`), dead-FCM-token pruning, batch caps on scheduled jobs, explicit `[STOCK_RELEASE_FAILED]` error breadcrumbs with manual-remediation notes.
- **Honest comments:** the codebase explains *why* (broadcast design, token-refresh ticker, deliberate villages duplication) — rare and valuable.
- **CI runs real test layers** (analyze + unit + functions) with dependency caching on every PR.

## 6. Unknowns and assumptions

| # | Unknown | Why it matters | How to resolve |
|---|---|---|---|
| U-1 | Whether `CLOUDINARY_API_SECRET`/`_KEY` are actually set in Secret Manager | `getCloudinarySignature` fails at runtime if unset | `firebase functions:secrets:access CLOUDINARY_API_KEY` |
| U-2 | GitHub secrets (`FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_PROJECT_ID`) exist/valid | deploy.yml correctness (once M-4 is fixed) | Check repo Settings → Actions |
| U-3 | Git history contains the old Cloudinary secret | Rotation requirement | Search history; rotate regardless (console action) |
| U-4 | Keystore backup durability | App identity loss risk | Business action |
| U-5 | Play Console account age (closed-testing 12×14 requirement) | Launch calendar | Business action |
| U-6 | Whether true rules-emulator tests exist anywhere | I-5 severity | Run a grep for `rules-unit-testing` imports in a full checkout |
| U-7 | iOS as a real target | Effort allocation | Product decision |

## 7. Prioritized remediation roadmap

### 0–30 days (launch gate)
1. **M-2** — Fix Android applicationId/namespace; create the Firebase Android app under the final ID; make release builds fail without `key.properties`. *(S)*
2. **M-4** — Repair the deploy workflow to actually deploy functions/rules/indexes. *(S)*
3. **H-1** — Standardize ledger actor key (`actorId`/`actorType`) across writers. *(S)*
4. **M-7** — Archive/delete the 16 stale legacy docs; adopt `docs/context/` as canonical; fix README links (I-1). *(S)*
5. **U-1/U-2** — Verify secrets exist (Secret Manager + GitHub). *(S)*
6. **M-6** — Correct CLAUDE.md's Riverpod/Freezed section. *(S)*

### 30–90 days (hardening)
7. **M-3** — First test tranche: AuthProvider role-discovery + cart/checkout logic tests; wire Playwright into CI as an optional job. *(L)*
8. **M-5** — TTL policies on `inventoryLogs` (+ decide support-message retention). *(S)*
9. **I-5** — True emulator-based rules tests for the order status machine. *(M)*
10. **M-1** — Continue `admin_home_screen.dart` decomposition (order queue + inventory flows into providers). *(M)*
11. **L-1/L-2** — Decide public product-read policy; add LICENSE. *(S)*

### 90+ days (scale & polish)
12. **I-4** — Cursor-paginate admin/history streams as volume grows. *(M)*
13. **I-2/L-5** — Remove the Node-backend branch and redundant seeders. *(S)*
14. **I-3** — Rider credential self-service (email reset), retire temporary-password handoff. *(M)*
15. **L-3** — Replace in-memory rate limiting with a durable counter if volume justifies it. *(M)*

### Quick wins (do today, each <30 min)
- Decide + set the applicationId (blocks everything store-related).
- Point `deploy.yml` at real `firebase deploy --only functions,firestore:rules,firestore:indexes`.
- Delete the two 0-byte `firestore-debug.log` files.
- Fix CLAUDE.md's state-management section.
- `git mv` legacy docs into `docs/legacy/` and drop a README pointer to `docs/context/`.
