# Production readiness — action plan and status

Scope: all three dashboards (customer, rider, admin) across model, view and
controller layers plus the Cloud Functions / rules backend.

**Verdict: not release-ready for the public store yet. It is a release candidate
for a staging / closed-beta rollout.** Every code-level blocker found in the
audit is fixed and covered by tests; what remains needs the project owner
(deploys, device QA, store paperwork, two business decisions).

Verification at the time of writing: backend 205/205 tests (15 suites, run
against the Firestore + Auth emulators), Flutter 127/127 tests, `flutter
analyze` = 0 errors / 0 warnings (only pre-existing deprecation infos).
Nothing here was run on a physical device or against the production Firebase
project.

## Plan and outcome

| # | Item | Layer | Status |
|---|---|---|---|
| 1 | Missing Firestore indexes: `orders(deliveryBoyId, createdAt↓)`, `supportTickets(customerId, updatedAt↓)`, `supportTickets(status, updatedAt↓)` (emulators don't enforce indexes; prod would fail) | Data | Fixed in `firestore.indexes.json` — **needs deploy** |
| 2 | Login errors leaked a default password and confirmed which emails exist | View | Fixed (generic messages) |
| 3 | Startup failure left a blank screen | Controller | Fixed (error screen + retry); async errors no longer reported as fatal |
| 4 | Shared listeners/state never reset on logout or account switch; pushed screens survived a forced logout | Controller | Fixed (`resetSession`, self-healing `SharedStream`, pop-to-root) + tests |
| 5 | Support rules let a customer edit any ticket field and post as `admin` | Security | Fixed + 15 rules tests — **needs deploy** |
| 6 | `deleteAccount`: no active-order guard, PII left in orders/tickets/profile | Compliance | Fixed + 6 tests; reason now shown to the user |
| 7 | Prescription medicines sellable with no verification | Compliance | **Blocked** server- and client-side (decision needed, see below) |
| 8 | Rider earnings repriced from the current rate; unbounded streams | Data | Payout frozen on the order at delivery; customer (100) and rider (200) streams bounded |
| 9 | Rider broadcast pushed ~960×/order | Backend | Capped at 10 broadcasts, then stops and is logged |
| 10 | CI: emulator tests ran without an emulator; Flutter pinned too old to compile | Release | Fixed in `ci.yml` |
| 11 | Release builds could be silently debug-signed | Release | Fixed: build fails without `android/key.properties` |
| 12 | Privacy policy / terms hardcoded | Product | Admin-editable in Store Settings (bundled text is the fallback) |
| 13 | Location capture: no timeout/accuracy/mock check/settings path, triplicated | View | `LocationService` + tests; placeholder tile user-agent fixed |
| 14 | Dead code (9 files), Node-backend path, unused `sendTestPush`, views importing the data layer | Hygiene | Removed / rerouted through providers |

## Still open — owner actions before public release

1. **Deploy** rules, indexes and functions to the production project
   (`firebase deploy --only firestore:rules,firestore:indexes,functions`) and
   confirm the three indexes finish building. Deleted-rider access, support
   rules, `deleteAccount`, payout snapshot, prescription block and broadcast cap
   are only live after this.
2. **Commit** the work (150+ files are uncommitted) and tag a build.
3. **Device QA** of all three dashboards on a real phone, including 320 px width
   and large system font. No screen has been seen rendering.
4. **Prescription decision.** Either build prescription upload + pharmacist
   verification and lift the block in `placeOrder`, or remove the flag. Selling
   Rx medicines without verification is not acceptable.
5. **Map/geocoding provider.** Free Nominatim and CARTO tiles are for light use;
   pick a commercial provider (Mappls, Google, Mapbox) before real traffic.
6. **Store paperwork:** Play data-safety form, App Store privacy details, and
   publish real privacy/terms text in Store Settings.
7. **Console settings:** enforce App Check, enable point-in-time recovery /
   backups, set budget and error-rate alerts, alert on
   `[STOCK_RELEASE_FAILED]` and `[BROADCAST_EXHAUSTED]`.
8. Confirm the Cloudinary secrets are set and no seeded accounts exist in the
   production Auth tenant.

## Deliberately deferred (not blockers, tracked)

- In-memory rate limiter is per instance (OTP and order paths are additionally
  protected server-side); move to a shared store if abuse appears.
- 39 hardcoded `Color(0x…)` values in screens bypass the design tokens.
- `OrderProvider` uses one `_isLoading` flag for unrelated actions.
- Web/desktop platform folders and `web` App Check provider: decide whether
  those targets ship; delete the folders if not.
- Rider earnings are summed on the client over the latest 200 orders — fine for
  "recent", not an all-time ledger.
- Old `products` / `orders` screens still show some hardcoded delivery-time copy.
