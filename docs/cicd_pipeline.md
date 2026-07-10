# CI/CD Build Pipeline Guide - BlinkBasket

BlinkBasket uses automated pipelines (e.g. GitHub Actions) to run syntax testing and generate Android debug and release APKs.

---

## 1. Local Verification Commands
Before pushing changes, run the following verification pipeline locally:

```bash
# Fetch latest dependencies
flutter pub get

# Run style checks and static analyzer
flutter analyze

# Run unit and repository tests
flutter test
```

---

## 2. GitHub Actions Configuration (`.github/workflows/flutter_ci.yml`)

```yaml
name: Flutter Integration Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-and-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Check syntax and analysis
        run: flutter analyze

      - name: Run unit tests
        run: flutter test

      - name: Compile Android Release APK
        run: flutter build apk --release
```
