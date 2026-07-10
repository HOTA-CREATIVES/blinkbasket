# Product Requirements Document (PRD) - BlinkBasket

## 1. Vision & Objectives
BlinkBasket is a hyperlocal quick-commerce application designed to deliver fresh groceries, household supplies, and emergency essentials to users' doorsteps within 10-15 minutes. The main objective is to reduce delivery times in rural and suburban areas (villages) through a network of local dark stores and whitelisted partners.

---

## 2. Target Personas
1.  **Asha (Customer):** A household shopper living in a suburban village. She needs fresh vegetables and cooking ingredients quickly but has inconsistent internet connectivity and prefers Cash on Delivery.
2.  **Ravi (Delivery Partner):** A local resident with a motorcycle. He wants a flexible way to earn money by picking up packages from the local store and navigating to villages he is already familiar with.
3.  **Kiran (Store Manager / Admin):** Manages inventory counts and assigns incoming orders to available riders.

---

## 3. Core Features & Scope
*   **Customer App:** Location detection (GPS with manual village dropdown selection fallback), catalog search, cash-on-delivery (COD) cart, real-time order status tracking.
*   **Rider App:** Online/offline duty toggle, geo-fenced tasks stream, navigation assistance, COD collection verification.
*   **Admin Console:** Inventory product creation/updates, order board, rider assignment.

---

## 4. Feature Prioritization (MoSCoW)

### Must Have (P0)
*   OTP-based mobile login.
*   Category-based catalog and shopping cart.
*   Checkout with Cash on Delivery (COD).
*   Admin assignment of riders.
*   Rider status update flows.

### Should Have (P1)
*   Real-time map tracking of the delivery partner.
*   Biometric unlock for Administrator login sessions.
*   Low-stock alerts for store managers.

### Could Have (P2)
*   Scheduled deliveries.
*   Subscription plans for dairy/daily essentials.

### Won't Have (P3)
*   Online credit/debit card payment gateway integration (restricted to Cash on Delivery).
