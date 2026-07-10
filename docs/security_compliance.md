# Security & Compliance Documentation - BlinkBasket

This document defines privacy compliance rules and authorization guidelines for data handling in BlinkBasket.

---

## 1. Data Privacy Compliance
BlinkBasket collects minimal personal identifiers (mobile phone numbers, street addresses, village locations) to facilitate hyperlocal delivery runs:

*   **Data Access Boundaries:** Customer addresses and phone numbers are only shared with the assigned delivery partner and store administrators. They are hidden from other users.
*   **Immutable Logs:** All critical events (logins, order creations, state transitions) publish immutable audit documents in Firestore for tracking purposes.

---

## 2. Authentication Controls
*   **Role-Based Access Control (RBAC):** Access permission checks are executed at the client boundary.
*   **Biometric Verification:** Biometric APIs (`local_auth`) lock administrative screens to prevent unauthorized access if the device is lost or compromised.
