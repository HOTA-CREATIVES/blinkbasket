# Action Plan

## Purpose
Turn the audit into an executable, owned sequence. Each item: what, why, how, done-when. Severities reference [FINDINGS.csv](FINDINGS.csv) / [AUDIT_REPORT.md](AUDIT_REPORT.md).

## Guiding principle
The app is close to shippable. The 0–30 day band is **entirely small, mechanical work** (identity, CI, one schema fix, doc curation) — none of it requires redesign. Defer everything architectural until the store identity is locked.

## Phase 1 — Launch gate (0–30 days, ~3–4 dev-days total)

### A1. Lock the Android release identity (M-2) — *business decision + 0.5 d*
- **Do:** Choose the final applicationId (e.g. `com.jcmart.app`). Register the Android app under it in the Firebase console; download new `google-services.json`; update `build.gradle.kts` `namespace` + `applicationId`; update `firebase.json` flutter.android mapping; re-run `flutterfire configure`.
- **Harden:** change the release `signingConfig` fallback from debug keys to a hard failure (`throw GradleException("key.properties missing")`).
- **Done when:** `flutter build appbundle --release` produces a signed aab under the final ID; Firebase console shows the new app.

### A2. Make CI deploy real things (M-4) — *0.25 d*
- **Do:** Replace the hosting-deploy step with `firebase deploy --only functions,firestore:rules,firestore:indexes --project ${{ secrets.FIREBASE_PROJECT_ID }}` using a service-account secret (or `w9jds/firebase-action`). Add a `firebase deploy --only storage` step (rules exist). Add web Hosting **only if** web launch is desired.
- **Done when:** a commit to main deploys functions and rules and the workflow log shows success.

### A3. Standardize the ledger actor key (H-1) — *0.25 d*
- **Do:** In `functions/src/index.ts` replace `adminId:` with `actorId:` in the three ledger writers (placeOrder, verifyDeliveryOtp, onOrderWritten) and keep `actorType`. Keep the DTO's `adminId` fallback for old docs. Optionally add a console one-off backfill later.
- **Done when:** grep shows no `adminId:` writes in functions; functions tests updated and green.

### A4. Curate documentation (M-7, M-6, I-1) — *0.25 d*
- **Do:** `git mv` the 16 legacy docs into `docs/legacy/` (add `docs/legacy/README.md`: "superseded by docs/context/ — historical claims are stale"). Rewrite CLAUDE.md's "Quick Commerce Guidelines" to describe Provider/DTO reality. Rewrite README.md links to relative paths (`docs/context/…`).
- **Done when:** no doc outside `docs/legacy/` contradicts the code.

### A5. Verify secrets & third-party consoles (U-1..U-3) — *0.25 d, ops*
- **Do:** `firebase functions:secrets:access CLOUDINARY_API_SECRET/_KEY` (set if missing); rotate the Cloudinary secret if the old client-side one is still active; confirm GitHub Actions secrets exist.
- **Done when:** `getCloudinarySignature` succeeds against production from the app.

### A6. Hygiene deletions (L-5, L-6, L-4) — *0.25 d*
- **Do:** delete 3 of the 4 seed entry points (keep `scripts/seed.js`); delete the 0-byte debug logs; either wire `AdminProfileScreen` into the admin UI or remove it.
- **Done when:** one seeder remains; no dead route.

## Phase 2 — Hardening (30–90 days)

### B1. Test tranche 1 — client business logic (M-3)
- AuthProvider role discovery (customer/rider/admin/inactive/UID-mismatch paths), CartProvider math + persistence, checkout preview math vs server contract. Target: every provider has at least a failure-path test.
### B2. True rules tests (I-5)
- Emulator-based rules tests (`@firebase/rules-unit-testing` is already a devDep) covering the order status machine, OTP privacy, and the rider self-edit allowlist. Replace (or keep as smoke) the mirrored-logic suite.
### B3. Retention (M-5)
- TTL policy on `inventoryLogs.timestamp` (~18 months); decide `supportTickets/messages` retention; document both in DATA_MODEL.md.
### B4. Continue admin decomposition (M-1)
- Move order-queue assignment/override flows and inventory adjustment flows into `AdminProvider`(+ use cases); `admin_home_screen.dart` target <800 lines.
### B5. Compliance hygiene (L-2)
- Add the LICENSE the business intends; align package.json.

## Phase 3 — Scale & polish (90+ days)

- **C1 (I-4):** cursor pagination on `streamAllOrders`, ledger streams, rider streams when order volume approaches caps (300/200).
- **C2 (I-2):** delete `HttpOrderRepository` Node branch or ship the server; single source of order transport.
- **C3 (I-3):** rider password self-service via Firebase email reset; retire `temporaryPassword` handoff.
- **C4 (L-3):** durable rate limiting (Firestore counter or App Check-only posture) if volume justifies.
- **C5:** decide iOS: either full QA/signing pass or freeze the platform claim to Android+Web.

## Tracking table

| ID | Action | Owner type | Band | Est. |
|---|---|---|---|---|
| A1 | Release identity + signing hard-fail | biz + dev | 0–30 | 0.5 d |
| A2 | Fix deploy workflow | dev | 0–30 | 0.25 d |
| A3 | Ledger actor key standardization | dev | 0–30 | 0.25 d |
| A4 | Doc curation (legacy archive, CLAUDE.md, README) | dev | 0–30 | 0.25 d |
| A5 | Secrets verification/rotation | ops | 0–30 | 0.25 d |
| A6 | Hygiene deletions | dev | 0–30 | 0.25 d |
| B1 | Provider/use-case tests | dev | 30–90 | 3 d |
| B2 | Emulator rules tests | dev | 30–90 | 1 d |
| B3 | TTL policies | dev+ops | 30–90 | 0.5 d |
| B4 | Admin decomposition phase 2 | dev | 30–90 | 2 d |
| B5 | LICENSE | biz | 30–90 | 0.1 d |
| C1 | Pagination | dev | 90+ | 1 d |
| C2 | Node-branch removal | dev | 90+ | 0.25 d |
| C3 | Rider self-service reset | dev | 90+ | 1 d |
| C4 | Durable rate limiting | dev | 90+ | 1 d |
| C5 | iOS go/no-go | biz | 90+ | decision |

## Done-when definition for "launch-ready"
All Phase-1 items checked + one full manual persona pass (customer order → rider deliver with OTP → admin ledger shows `sale` with a single actor key) + `flutter analyze`/`flutter test`/functions-jest green on the release branch.
