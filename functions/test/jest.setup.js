// Runs before each test file's module registry is populated, so the Admin
// SDK picks up the emulator hosts before `initializeApp()` runs in src/index.ts.
process.env.GCLOUD_PROJECT = "demo-hypermart";
process.env.FIRESTORE_EMULATOR_HOST = "localhost:8090";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "localhost:9099";
