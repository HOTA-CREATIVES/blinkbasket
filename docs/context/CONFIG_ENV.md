# Config & Environment

## Purpose
Every env var, dart-define, secret, and config source — and how they layer.

## Key facts

### Compile-time defines (Dart)
| Define | Values | Effect | Set where |
|---|---|---|---|
| `USE_FIREBASE_EMULATOR` | `true`/`false` (default false) | Wires Auth :9099, Firestore :8090, Functions :5001 to local emulators; disables App Check + Firestore persistence | [emulator_config.dart](../../lib/core/config/emulator_config.dart) |
| `EMULATOR_HOST` | host string (default: `10.0.2.2` on Android, `localhost` web, `127.0.0.1` other) | Overrides emulator host for device-on-LAN testing | same |
| `USE_FIREBASE_EMULATOR` (web build) | `true` | `npm run build:web` passes it to `flutter build web` | [package.json](../../package.json) |

### Runtime toggles (source constants — change = rebuild)
| Toggle | Location | Default |
|---|---|---|
| `BackendConfig.useNodeBackend` | [backend_config.dart](../../lib/core/services/backend_config.dart) | `false` (Node-backend branch is dead code) |
| `CLOUDINARY_CLOUD_NAME` / `CLOUDINARY_UPLOAD_FOLDER` | [index.ts:12-13](../../functions/src/index.ts#L12-L13) | `diiyy6bar` / `products` |

### Cloud Functions environment (geocoding proxy)
| Variable | Default | Effect |
|---|---|---|
| `GEOCODER_BASE_URL` | `https://nominatim.openstreetmap.org` | Nominatim-compatible API used by `reverseGeocode` / `searchAddress`. Point it at a paid provider for production scale — the public instance's usage policy does not allow heavy commercial use. |
| `GEOCODER_CONTACT_EMAIL` | `support@jcmart.app` | Sent in the `User-Agent` so the geocoder can contact the operator. Set a real, monitored address. |

Results are cached in `/geocodeCache` (30 days); set a Firestore TTL policy if you want old entries reaped. Rate-limit counters live in `/rateLimits` — set a TTL policy on `expireAt`.

### Admin config flags (`/config/app`)
| Field | Default | Effect |
|---|---|---|
| `requireVerifiedEmail` | `true` | `placeOrder` refuses email/password accounts whose email is unverified. Set `false` only while email delivery is broken. |
| `serviceZones` | built-in villages, 12 km | Delivery zones (`name`, `lat`, `lng`, `radiusKm`) used by the app and by `placeOrder` / `searchAddress`. |

### Secrets
| Secret | Storage | Access |
|---|---|---|
| `CLOUDINARY_API_SECRET` | Firebase Secret Manager (`defineSecret`) | only `getCloudinarySignature` CF |
| `CLOUDINARY_API_KEY` | Firebase Secret Manager | same CF |
| Firebase web API keys | `lib/firebase_options.dart` (generated) | public-by-design client config |
| Android release keystore | `android/key.properties` + `upload-keystore.jks`, **git-ignored** ([.gitignore:51-53](../../.gitignore#L51-L53)) | signing config falls back to debug keys if absent |

No `.env` files anywhere; no `--dart-define` secrets; CI uses only `GITHUB_TOKEN`-derived secrets (`FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_PROJECT_ID` referenced in deploy.yml).

### Runtime data config (Firestore `config/app`)
Admin-editable in Store Settings, read live by all clients: `storeOpen` (checkout gate), `deliveryFee`, `freeDeliveryAbove`, `etaLabel`, `riderPayoutPerDelivery`, `supportPhone`, `supportWhatsapp`, `categories[]`.
`config/dashboard_stats` is written only by trigger functions (self-healing via set+merge).

### CI/CD environment
| Workflow | Trigger | Steps |
|---|---|---|
| [ci.yml](../../.github/workflows/ci.yml) | push to main/develop, PRs to main | `flutter analyze` (3.27.x), `flutter test`, functions `npm ci && build && test` (node 20, npm cache) |
| [deploy.yml](../../.github/workflows/deploy.yml) | push to main | functions `npm ci && build && test`, then **FirebaseExtended/action-hosting-deploy** |

⚠️ deploy.yml uses the **Hosting** deploy action with no hosting config in [firebase.json](../../firebase.json) — functions are *not* deployed by CI; deployment is manual (`npm --prefix functions run deploy`). See audit M-4.

### Local dev loop
```bash
flutter pub get
npm --prefix functions install
npm run emulators          # auth+firestore+functions on :9099/:8090/:5001
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
npm --prefix functions test
flutter test && flutter analyze
npm run seed               # scripts/seed.js (one of four seed entry points)
```

### Bootstrap a fresh Firebase project (reverse-engineered sequence)
1. Create project, enable Email/Password + Google auth providers.
2. `flutterfire configure` (writes `firebase_options.dart`, `google-services.json`).
3. `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`.
4. Console: create first `admins/{uid}` doc (doc ID **must** be the admin's auth UID) → `onAdminWritten` sets the claim.
5. Seed `config/app` (via admin Store Settings) — `dashboard_stats` self-heals.
6. Register Play App Signing SHA-256 in Firebase App Check console **after** first Play upload, or every `enforceAppCheck` callable rejects real users.

### Config precedence (runtime values)
Server config (`config/app`) > client fallback constants (e.g. `placeOrder` defaults fee=30, freeAbove=300 if doc missing) > hard-coded widget defaults. Compile-time defines only affect emulator/dev wiring.

## Open questions / unknowns
- `FIREBASE_SERVICE_ACCOUNT` / `FIREBASE_PROJECT_ID` GitHub secrets — cannot verify from repo whether they're configured; deploy workflow is currently broken/mismatched regardless (M-4).
- No staging environment: `build:web` + emulator is the only "staging". Is a separate Firebase project planned?
- `.firebaserc` pins one project (`hypermart-ee8ef`) with no aliases — dev/prod isolation doesn't exist.
