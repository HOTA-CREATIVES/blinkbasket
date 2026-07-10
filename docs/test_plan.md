# Test Plan & Strategy - BlinkBasket

This document defines the testing approach for ensuring the stability and performance of the quick-commerce system.

---

## 1. Testing Scope & Strategy

### 1.1 Unit Tests
*   **Target:** Pure Dart domain logic and entities (`Product`, `Order`).
*   **Goal:** Verify state transformations and cart calculations (e.g. totaling amounts, item incrementing).
*   **Command:** `flutter test test/unit/`

### 1.2 Integration Tests
*   **Target:** Data repositories interacting with mock Firestore services.
*   **Goal:** Verify database writes, atomic stock decrement transactions, and stream listeners.
*   **Command:** `flutter test test/integration/`

### 1.3 User Acceptance Testing (UAT)
*   **Target:** Core end-to-end user journeys (placing order, assigning rider, rider delivering, customer tracking status update).

---

## 2. Test Execution Workflow
All test runs must show **100% pass rates** inside the CI/CD pipeline before branch merges.
*   Run syntax analyzer: `flutter analyze`
*   Run unit tests: `flutter test`
