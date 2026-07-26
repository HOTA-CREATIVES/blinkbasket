# Play Store Launch Checklist — J C Mart (Android)

Verified against the repo state as of 2026-07-19. Every item traces to a specific file — re-check line numbers if the referenced file has moved since.

## Blockers — won't submit, or shouldn't go live, without these

- [ ] **Change the application ID off the Flutter template default.**
  `applicationId = "com.example.hypermart"` in `android/app/build.gradle.kts:39` — still has the literal `// TODO: Specify your own unique Application ID` comment above it. Google rejects `com.example.*` packages outright, and once published the ID can **never** be changed. Pick the real one now (e.g. `com.jcmart.app`) and update it in `build.gradle.kts`, `google-services.json`, and `firebase.json`'s Flutter Android `appId` mapping.

- [ ] **Fix the placeholder Google Sign-In support email.**
  `firebase.json:7` has `"supportEmail": "support@undefined.firebaseapp.com"` — a literal placeholder shown to every user on the Google Sign-In consent screen. Set a real, monitored support address in the Firebase Auth / GCP OAuth consent screen config.

- [ ] **Register the Play App Signing certificate for App Check / Play Integrity.**
  `lib/main.dart:39-43` activates `AndroidProvider.playIntegrity` for release — correct — but it only works once the SHA-256 fingerprint registered in the Firebase App Check console is Google's **Play App Signing** certificate (visible in Play Console → Setup → App integrity *after* your first upload), not the local `upload-keystore.jks` fingerprint. Miss this and every `enforceAppCheck: true` callable (`placeOrder`, `acceptOrder`, `verifyDeliveryOtp`, …) silently rejects every real user while working fine in local testing.

- [ ] **Confirm targetSdkVersion clears Play's current minimum.**
  The installed Flutter SDK (`3.29.0`, Feb 2025) resolves `flutter.targetSdkVersion` in `build.gradle.kts:43`. Play Console enforces a rolling minimum target API level that moves forward roughly yearly — an SDK this old risks resolving below it. Run `flutter upgrade` (or at minimum verify the resolved target SDK against Play Console's current requirement) before the first upload attempt.

- [ ] **Write and host a public Privacy Policy.**
  No privacy policy file exists in the repo. Required in the Play Console store listing, and non-optional here: the app collects precise location (`ACCESS_FINE_LOCATION`, `AndroidManifest.xml:3`), phone number, name, order history, and — per `storage.rules:16-24` — prescription image uploads, which pushes this into sensitive/health-adjacent data for Play's Data Safety review. Write it to match actual behavior, not a generic template.

- [ ] **Complete the Data Safety form accurately.**
  Must declare, truthfully: precise location, name, phone number, purchase/order history, and prescription images (health data), with actual purpose (app functionality / COD delivery) and third-party sharing (Cloudinary for images, Firebase for everything else). A mismatch between this form and actual app behavior is a policy-violation takedown risk, not just a listing-quality issue.

## High priority — will pass review, but you'll regret shipping without them

- [ ] **Add crash reporting.**
  `lib/main.dart:29-63` wraps Firebase init in a bare `try/catch` that only does `debugPrint` — invisible once shipped. No `firebase_crashlytics` dependency, no `FlutterError.onError` / `PlatformDispatcher.instance.onError` hook, no Sentry. Today, a production crash is reported to no one. Add Crashlytics (or equivalent) before launch.

- [ ] **Back up the release keystore somewhere durable.**
  `android/app/upload-keystore.jks` and `android/key.properties` exist locally and are correctly gitignored (`.gitignore:51-53`) — good for secrecy, bad for durability. If this machine is lost before the keystore is backed up to a password manager or secure vault, you lose the ability to publish any future update under this app identity.

- [ ] **Budget for the closed-testing requirement (new/personal accounts).**
  Play Console requires new developer accounts to run a closed test with 12+ opted-in testers for 14 continuous days before a production release unlocks. If this Play Console account hasn't published before, this is calendar time that cannot be compressed — start it in parallel with the blocker fixes above.

- [x] **Enable R8 shrinking for the release build.** ✅ 2026-07-19
  Enabled `isMinifyEnabled`/`isShrinkResources` in `android/app/build.gradle.kts` and added a starter `android/app/proguard-rules.pro`. Verified with a real `flutter build appbundle --release`: **app-release.aab is 30.0MB** (down from a 109MB *debug* APK, which was never the real ship size to begin with). Re-test the release build after any new plugin/dependency is added — R8 stripping issues surface as runtime crashes, not build failures.

- [ ] **Generate an adaptive icon.**
  Only legacy square PNGs exist (`mipmap-*dpi/ic_launcher.png`) — no `mipmap-anydpi-v26` adaptive icon. Play Console will flag this at upload, and the launcher icon won't respect the device's icon mask on Android 8+. `flutter_launcher_icons` generates this from one source image.

- [ ] **Enable Firestore Point-in-Time Recovery.**
  This is a COD order/payments-adjacent system with no visible backup configuration in the repo (expected — it's a console setting, not code). Confirm PITR or scheduled exports are turned on for the `hypermart-ee8ef` project before real orders start flowing through it.

- [ ] **Set a GCP budget alert.**
  `escalateStaleOrders` runs every minute forever by design (no admin fallback — see its docstring in `functions/src/index.ts:901-911`), and every callable enforces App Check but has no explicit `maxInstances`. Reasonable at current scale; put a billing alert in place so a traffic spike or abuse pattern surfaces as a notification, not a bill.

## Recommended — worth doing, not urgent

- [ ] **Clean up naming drift.** Store listing name is "J C Mart" (`AndroidManifest.xml:8`), but the root widget is still `BlinkBasketApp` (`lib/main.dart:57,83`), the FCM notification channel ID is `blinkbasket_orders` (`AndroidManifest.xml:14`), and the Firebase project ID is `hypermart-ee8ef` — three earlier project names surviving in one codebase. Not user-visible today; worth a rename pass.

- [ ] **Hoist the rider-candidates query out of the escalation loop.** `escalateStaleOrders` (`functions/src/index.ts:912-945`) re-runs the same `deliveryBoys` on-duty query inside its per-order loop. It's the same pool for every stale order in a batch — query it once before the loop.

- [ ] **Prune dead FCM tokens.** `sendPushToTokens` (`functions/src/index.ts:89-105`) catches multicast failures but never removes tokens that come back `registration-token-not-registered`. Over time, uninstalled-app tokens accumulate in `fcmTokens` arrays, quietly inflating every push call.

- [ ] **Clamp `adjustStock` against negative stock.** `firebase_product_repository.dart:80-128`'s admin restock/correction path has no floor guard, unlike its Cloud Function equivalents which use `Math.max(0, …)`. Admin-only surface, low severity.

- [ ] **Do one full manual QA pass across all three personas on a real device.** Customer checkout → rider accept/pickup/deliver with OTP → admin dashboard, on a physical Android device, exercising the COD + location + push-notification paths together.

## Store listing assets

| Asset | Spec | Required |
|---|---|---|
| Hi-res app icon | 512×512 PNG, 32-bit with alpha | Yes |
| Feature graphic | 1024×500 JPG/PNG | Yes |
| Phone screenshots | 2–8 images, 16:9 or 9:16 | Yes |
| Short description | ≤80 characters | Yes |
| Full description | ≤4000 characters | Yes |
| Content rating questionnaire | Completed in-console | Yes |
| App category + tags | e.g. Shopping | Yes |
| Release format | Android App Bundle (`.aab`), not a raw APK — `flutter build appbundle` | Yes |
