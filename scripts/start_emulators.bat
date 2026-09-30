@echo off
REM Starts the Firebase Local Emulator Suite for J C Mart.
REM Run this from the repository root, then seed with: npm run seed
setlocal

echo =======================================================
echo   Firebase Local Emulator Suite - J C Mart
echo =======================================================
echo.
echo   Auth       http://localhost:9099
echo   Firestore  http://localhost:8090
echo   Functions  http://localhost:5001
echo   Emulator UI http://localhost:4000
echo.
echo   Then run the app:
echo     flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
echo.

REM The Auth emulator needs the sign-in provider endpoints enabled, otherwise
REM the seeded email/password accounts exist but the client can never obtain
REM an ID token for them.
set FIRESTORE_EMULATOR_HOST=127.0.0.1:8090
set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099

firebase emulators:start --only auth,firestore,functions --project hypermart-ee8ef
