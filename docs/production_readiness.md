# Production Readiness Checklist - BlinkBasket

This checklist must be fully signed off by QA and lead developers before any production deploy (publishing to App Store/Play Store).

---

## 1. Security & Authentication Checks
- `[ ]` **Biometric Lockdown:** Confirm biometric fingerprint authentication is mandatory before entering the Admin module page.
- `[ ]` **Firestore Rules:** Verify read/write permissions are restricted via custom rules. No collection should allow open wildcard writes.
- `[ ]` **Auth whitelist:** Confirm only whitelisted delivery phone numbers and emails can access partner roles.

---

## 2. Performance & Optimizations
- `[ ]` **Asset sizes:** Confirm SVG image files are compressed and registered correctly in `pubspec.yaml`.
- `[ ]` **Index Validation:** Verify all composite query indexes (e.g. `orders` customer streams) are deployed and active in the Firebase Console.
- `[ ]` **Release Mode build:** Verify tests pass under release compilation:
  ```bash
  flutter build apk --release
  ```

---

## 3. Operations & Compliance
- `[ ]` **COD Terms:** Cash on Delivery instructions are clearly displayed at checkout.
- `[ ]` **Terms of Service:** App privacy statements are accessible in the profile setup screen.
