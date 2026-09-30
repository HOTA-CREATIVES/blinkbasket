# Launch Runbook — Manual/Console Steps

This is the checklist of everything left to launch that **cannot be fixed by
editing the repo** — Play Console clicks, Firebase console settings, GCP
billing, and decisions only the business owner can make. Every code-level
gap that could be fixed has been (see git history / `PRODUCTION_PATCH_PLAN.md`
and `playstore_launch_checklist.md` for what those covered — re-verify both
against current code before trusting them, several of their items are
already resolved).

Work top to bottom; items are ordered so nothing blocks on something later
in the list.

## 1. Pick and lock in the real application ID

**Do this first — it's irreversible once published.**

`android/app/build.gradle.kts` still has `applicationId = "com.example.hypermart"`.
Google Play rejects `com.example.*` outright, and the ID can never change
after your first release.

1. Decide the real reverse-domain ID (e.g. `com.jcmart.app`).
2. In the [Firebase console](https://console.firebase.google.com) →
   Project settings → your Android app → register a **new** Android app
   under that package name (Firebase apps are tied 1:1 to package name; you
   can't just rename the existing one).
3. Download the new `google-services.json` and replace
   `android/app/google-services.json`.
4. Update `android/app/build.gradle.kts`: `namespace` and `applicationId`.
5. Update `lib/firebase_options.dart`'s iOS/macOS `iosBundleId` fields the
   same way if shipping iOS.
6. Update `firebase.json`'s `flutter.platforms.android.default.appId` to
   the new numeric App ID Firebase assigns.
7. Re-run `flutterfire configure` if available, or hand-verify the above
   four files agree.

## 2. Register the Play App Signing certificate for App Check

`lib/main.dart` activates `AndroidProvider.playIntegrity` for release builds,
and every sensitive callable (`placeOrder`, `acceptOrder`,
`verifyDeliveryOtp`, `reportDeliveryFailure`, …) has `enforceAppCheck: true`.
This only works once the **Play App Signing** SHA-256 fingerprint (visible
in Play Console → Setup → App integrity, *after* your first upload) is
registered in the Firebase App Check console — not your local
`upload-keystore.jks` fingerprint.

Miss this step and every real user's app is silently rejected on every
sensitive action while your own local testing keeps working fine.

Order of operations: upload the first release to Play Console (even to
internal testing) → copy the Play App Signing SHA-256 → add it in Firebase
console → App Check → the Android app → manage.

## 3. Firestore backups

Confirm in the Firebase console (Firestore → Backups, or via
`gcloud firestore backups schedules create`) that either Point-in-Time
Recovery or scheduled exports are turned on for the `hypermart-ee8ef`
project **before real COD orders start flowing**. There is no payment
gateway in this app — Firestore is the *only* record of what a customer
ordered and owes. Losing it loses the business's ability to reconcile COD
collections.

## 4. GCP budget alert

Set a billing budget alert (Billing → Budgets & alerts) at a threshold that
makes sense for expected order volume — the engineering estimate in
`PRODUCTION_PATCH_PLAN.md` §7 put pilot-scale usage at ~$0–5/month, so even
a $10–25/month alert threshold will catch a runaway traffic or abuse
pattern early. `escalateStaleOrders` runs every minute forever by design (no
manual admin-assign fallback exists — see its docstring in
`functions/src/index.ts`), so a stuck retry loop is the most likely source
of an unexpected spike.

## 5. Play Store account & listing

- **Closed testing requirement**: if this Play Console developer account
  has never published an app before, Play requires 12+ opted-in testers
  running a closed test for 14 continuous calendar days before a production
  release unlocks. This can't be compressed — start it in parallel with
  everything else on this list.
- **Store listing assets**: hi-res icon (512×512 PNG), feature graphic
  (1024×500), 2–8 phone screenshots, short description (≤80 chars), full
  description (≤4000 chars), content rating questionnaire, category. See
  `playstore_launch_checklist.md` for the full spec table.
- **Data Safety form**: declare, truthfully, everything in the "What we
  collect" table of the privacy policy (name, phone, precise location,
  order history, push token; shared with Firebase and, for product photos
  only, Cloudinary). A mismatch between this form and the app's actual
  behavior is a policy-violation takedown risk, not just a listing-quality
  one — re-check it against the privacy policy content whenever data
  collection changes.
- **Privacy policy URL**: a public, hosted privacy policy is required in
  the store listing. A ready-to-use one (matching the app's actual current
  data practices) was drafted and published — see the link shared alongside
  this runbook. **Before using it**: fill in the placeholder support
  email/phone in its Contact section — no real monitored contact address
  exists anywhere in this codebase today, so it was deliberately left as a
  placeholder rather than invented.

## 6. Keystore durability

`android/app/upload-keystore.jks` and `android/key.properties` exist
locally and are correctly gitignored — good for secrecy, bad for
durability. Back both up to a password manager or secure vault *now*. If
this machine is lost before that happens, no future update can ever be
published under this app's identity.

## 7. First admin account (one-time bootstrap)

`/admins/{uid}` in Firestore rules is `allow write: if false` for every
client — by design, there is no in-app or callable way to create the first
admin. Before launch, manually:

1. Create the admin's Firebase Auth account (console or `firebase auth:import`).
2. Write their `admins/{uid}` Firestore document directly in the console
   (the `onAdminWritten` trigger picks it up and sets the `admin` custom
   claim automatically — no need to set claims by hand).
3. Have them sign out and back in once so the new claim is picked up.

Write down who did this and when — it's the one privileged account with no
audit trail from within the app itself.

## 8. Flutter/Android SDK freshness — ✅ done 2026-09-03

Upgraded `3.29.0` → `3.47.2`. Resolved `targetSdkVersion`/`compileSdkVersion`
are now **36** (Android 16) via `flutter.targetSdkVersion` in
`android/app/build.gradle.kts` — comfortably ahead of Play's current rolling
minimum. `flutter analyze` and `flutter test` (101/101) both verified clean
on the new SDK; one real bug the newer analyzer caught along the way
(`firebase_auth_repository.dart`'s `refreshUserProfile` was returning an
un-awaited `Future` inside a `try` block, so a transient error could skip
its own `catch` and propagate unhandled) was fixed in the same pass. ~23
new Material API deprecation *infos* surfaced (`RadioListTile.groupValue`,
`DropdownButtonFormField.value`, `Switch.activeColor`, etc.) — none are
errors, all still work, left as a low-priority cleanup for later.

Not re-verified: a full native Android/iOS build (`flutter build appbundle`)
and a real-device run — do this as part of item 9 below, since it needs a
device anyway.

## 9. One full manual QA pass, on a real device

Automated tests (`flutter test`, `npm test` in `functions/`) are green, but
nothing here has been run through an emulator or a physical device this
session. Before submitting: customer checkout → rider accept → pickup →
out-for-delivery → OTP delivery (and separately, the new "Can't deliver
this order?" path) → admin dashboard, on a real Android device, exercising
COD + live location + push notifications together.

---

*Cross-reference: `PRODUCTION_PATCH_PLAN.md` and `playstore_launch_checklist.md`
were both written 2026-07-19 and are stale on several points already fixed
in code since — re-verify any item from either doc against current source
before acting on it, the way this runbook's own items were verified before
being written down.*
