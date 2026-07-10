# Software Requirements Specification (SRS) - BlinkBasket

## 1. Functional Requirements (FR)

### 1.1 Authentication Module
*   **FR-1.1:** System shall support phone number OTP and Google Sign-In authentication.
*   **FR-1.2:** System shall assign access roles (`customer`, `delivery`, `admin`) to user profiles.
*   **FR-1.3:** Administrators shall be forced to authenticate via device biometrics (fingerprint/face detection) prior to accessing command centers.

### 1.2 Customer Module
*   **FR-2.1:** Users shall be able to browse catalog items grouped by category tags.
*   **FR-2.2:** Users shall be able to add/remove/decrement items in their cart.
*   **FR-2.3:** Checkout shall be restricted strictly to Cash on Delivery (COD) payment.
*   **FR-2.4:** Placing an order shall atomically decrement catalogue stock limits in Firestore.
*   **FR-2.5:** Customers shall track active order timelines (Placed -> Assigned -> Picked Up -> Out for Delivery -> Delivered).

### 1.3 Rider Module
*   **FR-3.1:** Riders shall toggle availability status (online/offline).
*   **FR-3.2:** Riders shall view incoming tasks, address directions, and total cash collections.
*   **FR-3.3:** Riders shall transition order states to update customers and store managers.

### 1.4 Admin Console
*   **FR-4.1:** Admins shall manage catalog products (add, edit, delete).
*   **FR-4.2:** Admins shall assign pending orders to available delivery partners.

---

## 2. Non-Functional Requirements (NFR)

### 2.1 Performance
*   **NFR-1.1:** The database status synchronization (Firestore stream) must update clients in under 1 second.
*   **NFR-1.2:** Client-side cart computations must run instantly with 0ms latency.

### 2.2 Security
*   **NFR-2.1:** Authenticated routes shall be locked via role-based filters on the client wrapper.
*   **NFR-2.2:** Personal identifiers (phone numbers, street addresses) must be kept secure within Firestore security rules.
