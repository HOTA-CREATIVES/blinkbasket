# QA & UAT Test Cases - BlinkBasket

The following test scripts validate core features prior to system release.

---

## Test Case 1: Customer Order Checkout (COD only)
*   **Actor:** Customer
*   **Pre-conditions:** Logged in, items added to shopping cart.
*   **Procedure:**
    1.  Tap on the Floating Action Button to enter the Cart screen.
    2.  Verify address coordinates/village details are loaded from profile defaults.
    3.  Select Cash on Delivery as the payment method (assert no online option is shown).
    4.  Tap **PLACE ORDER**.
*   **Expected Result:** Cart is cleared, a notification displays success, and the screen routes to the Active Order History page. Stock count in Firestore decrements correctly.

---

## Test Case 2: Rider Assignment & Delivery Progress
*   **Actor:** Admin and Assigned Rider
*   **Pre-conditions:** Customer has placed a "pending" order.
*   **Procedure:**
    1.  Admin opens the Operations Desk and selects **ASSIGN DELIVERY BOY**.
    2.  Selects an online delivery boy.
    3.  Rider logs in, views the active task, and taps **PICK UP ITEMS**.
    4.  Rider arrives at the customer address and taps **MARK DELIVERED**.
*   **Expected Result:** Order status in Firestore changes to `assigned` -> `picked_up` -> `delivered`. The customer tracking timeline updates in real time.
