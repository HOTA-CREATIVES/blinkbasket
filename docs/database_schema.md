# Database Schema & Firestore Rules - BlinkBasket

This document defines the schema models and index rules configured on Cloud Firestore.

---

## 1. Document Collection Schemas

### `users` (Collection)
*   `uid` (String, DocumentId)
*   `name` (String)
*   `email` (String)
*   `phone` (String)
*   `village` (String)
*   `role` (String: `"customer"` | `"delivery"` | `"admin"`)
*   `isActive` (Boolean)
*   `createdAt` (Timestamp)

### `products` (Collection)
*   `productId` (String, DocumentId)
*   `name` (String)
*   `description` (String)
*   `price` (Double)
*   `category` (String)
*   `stock` (Integer)
*   `unit` (String: e.g. `"1 kg"`, `"500 g"`)
*   `imageUrl` (String)

### `orders` (Collection)
*   `orderId` (String, DocumentId)
*   `customerId` (String)
*   `customerName` (String)
*   `customerPhone` (String)
*   `deliveryAddress` (String)
*   `village` (String)
*   `items` (Array of Map):
    *   `productId` (String)
    *   `name` (String)
    *   `price` (Double)
    *   `quantity` (Integer)
*   `totalAmount` (Double)
*   `paymentMethod` (String: `"COD"`)
*   `status` (String: `"pending"` | `"assigned"` | `"picked_up"` | `"out_for_delivery"` | `"delivered"` | `"cancelled"`)
*   `deliveryBoyId` (String, Nullable)
*   `deliveryBoyName` (String, Nullable)
*   `createdAt` (Timestamp)
*   `updatedAt` (Timestamp)

---

## 2. Composite Query Indexes Required
To query order lists efficiently, the following composite indexes must be defined in the Firebase Console:

1.  **Collection:** `orders`
    *   `customerId` (Ascending) + `createdAt` (Descending)
2.  **Collection:** `orders`
    *   `deliveryBoyId` (Ascending) + `createdAt` (Descending)
