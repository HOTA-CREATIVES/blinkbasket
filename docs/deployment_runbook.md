# Deployment & Operations Runbook - BlinkBasket

This runbook outlines standard procedures for compiling release builds and deploying changes to Firebase configurations.

---

## 1. Firebase Deployments
If security rules (`firestore.rules`) or indexes (`firestore.indexes.json`) change:

1.  Log in to Firebase CLI:
    ```bash
    firebase login
    ```
2.  Deploy updated security configurations:
    ```bash
    firebase deploy --only firestore
    ```

---

## 2. Compiling Android Production Release (APK & App Bundle)

1.  **Configure App Signing:**
    *   Create a release keystore (`upload-keystore.jks`).
    *   Map keys in `android/key.properties` (Keystore path, passwords, alias).

2.  **Generate Google Play App Bundle (AAB):**
    ```bash
    flutter build appbundle --release
    ```

3.  **Generate Debug APK for Ad-hoc Testing:**
    ```bash
    flutter build apk --debug
    ```
