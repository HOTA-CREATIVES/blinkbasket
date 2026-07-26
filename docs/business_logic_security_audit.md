# Business-Logic & Security Audit — J C Mart

Audit date: 2026-07-19. Scope: the order lifecycle end to end — `functions/src/index.ts` (`placeOrder`, `verifyDeliveryOtp`, `acceptOrder`, triggers), `firestore.rules`, `storage.rules`, and the client repositories/usecases that call them. Read against the invariants documented in `CLAUDE.md`'s "Core domain rules" section.

## Verified sound

- **Stock safety.** `placeOrder` reserves stock and `verifyDeliveryOtp` decrements physical stock, both inside `runTransaction`, with `physicalStock`/`reservedStock`/`availableStock` updated together and a ledger entry written atomically in the same transaction. Cancellation release (`onOrderWritten`) does the same. Matches the `CLAUDE.md` stock-formula invariant exactly.

- **Race conditions.** `acceptOrder` and `verifyDeliveryOtp` both use read-then-conditional-write inside transactions, so concurrent riders accepting the same order, or double-submitted OTPs, resolve deterministically (`"taken"` / `"wrong_otp"` outcomes) rather than corrupting state. The wrong-OTP attempt counter persists across the transaction by returning a string outcome and throwing *after* commit, rather than throwing from inside (which would roll back the counter increment too).

- **Price integrity.** Enforced twice — `firestore.rules:74` (`price is number && > 0`) at the database layer, independent of `placeOrder` re-reading price server-side rather than trusting the client's cart total.

- **Store-open gate.** Checked server-side in `placeOrder` (`config.storeOpen === false` throws before any stock is touched).

- **OTP secrecy.** Lives in a `private` subcollection readable only by the order's own customer (`firestore.rules:118-122`). Wrong-OTP attempts capped at `MAX_OTP_ATTEMPTS = 5`.

- **Privilege boundaries.** Admin/delivery custom claims are only ever set by trigger functions (`onRiderWritten`, `onAdminWritten`) reading `admins`/`deliveryBoys` docs, which are themselves admin-write-only (`firestore.rules:44-47`, `51-67`). A rider can't self-promote. `acceptOrder` re-reads the live rider doc rather than trusting a possibly-stale JWT claim.

## Findings

| # | Where | Issue | Severity |
|---|---|---|---|
| 1 | `lib/data/repositories/firebase_product_repository.dart:80-128` (`adjustStock`) | No floor guard — an admin restock/correction with a bad negative delta can push `physicalStock`/`reservedStock` below 0. The server-side Cloud Function equivalents use `Math.max(0, …)`; this client path doesn't. | Low — admin-only surface, but a fat-fingered correction silently produces a negative-stock product visible to customers as available. Fix: clamp with `.clamp(0, ...)` on `newPhysical`/`newReserved`. |
| 2 | `firestore.rules:93-115` orders `allow update` | `isAdmin()` has no field restriction on order updates — an admin can hand-set `deliveryBoyId`/`status` directly, bypassing `acceptOrder`'s on-duty/active checks. | Informational — appears intentional (comment: "Admin: assign rider, cancel, correct" — an override escape hatch). Flagging in case it wasn't a deliberate bypass of rider-eligibility checks. |
| 3 | Repo-wide | `CLAUDE.md` mandates repositories return `Result<T>` instead of throwing; every repository (`firebase_product_repository.dart`, `firebase_order_repository.dart`, etc.) throws `Exception(...)`. Only `placeOrder`/`verifyDeliveryOtp`/`acceptOrder` follow a result-ish pattern (nullable-error string / named-constructor result). | Informational — a documented convention nobody's applied yet, not a bug. Worth reconciling the doc and the code either direction. |
| 4 | `functions/src/index.ts:17-18` | `CLOUDINARY_CLOUD_NAME`/`CLOUDINARY_API_KEY` are hardcoded constants. | Verified safe — cloud name and API key are meant to be public; only the API *secret* is Secret-Manager-gated (`cloudinaryApiSecret`), and it is. |

No open path to unauthorized stock manipulation, price tampering, order spoofing, or privilege escalation was found. Item 1 is the only actionable fix; the rest are informational.
