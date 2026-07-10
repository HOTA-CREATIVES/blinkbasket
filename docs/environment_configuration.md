# Environment Configuration Guide - BlinkBasket

BlinkBasket configures connection strings, API targets, and credentials for different environments (Development, Staging, Production).

---

## 1. Firebase Options Configurations
The project links directly to Firebase project projects using `lib/firebase_options.dart`. Make sure your configuration environment is set up as follows:

| Environment | Firebase Project ID | Purpose |
| :--- | :--- | :--- |
| **Development** | `hypermart-dev` | Local emulator and sandbox environment tests. |
| **Staging** | `hypermart-staging` | Internal QA testing and partner validation runs. |
| **Production** | `hypermart-prod` | Live user store deployments. |

---

## 2. API & Flag Constants (`lib/core/utils/config.dart`)
Configuration constants are compiled into the binary depending on the target environment target profile:

*   `bool const IS_PRODUCTION = false;` (Toggle to enable console debug logs).
*   `double const FREE_DELIVERY_THRESHOLD = 300.0;` (Cart value to waive delivery fee).
*   `double const BASE_DELIVERY_FEE = 30.0;` (Flat rate for delivery partner payouts).
