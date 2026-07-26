# HyperMart Data Models Documentation

This document outlines the core data models and entities used across the HyperMart Hyperlocal Commerce Platform.

---

## Table of Contents
1. [User & Address Models](#1-user--address-models)
2. [Product Model](#2-product-model)
3. [Order & OrderItem Models](#3-order--orderitem-models)
4. [Inventory Ledger Model](#4-inventory-ledger-model)
5. [App Config Model](#5-app-config-model)
6. [Banner Item Model](#6-banner-item-model)
7. [Dashboard Stats Model](#7-dashboard-stats-model)

---

## 1. User & Address Models

Defined in: `lib/core/models/user_model.dart`

### AddressModel
Represents customer delivery addresses with granular village/mandal and optional geo-coordinates.

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `id` | `String` | Required | Unique identifier for address |
| `name` | `String` | Required | Recipient / Label name |
| `addressLine1` | `String` | Required | Primary street address line |
| `addressLine2` | `String?` | Optional | Secondary address line / apartment |
| `pinCode` | `String` | Required | Postal Code |
| `village` | `String` | Required | Hyperlocal village location |
| `mandal` | `String` | Required | Mandal region |
| `landmark` | `String?` | Optional | Nearby landmark |
| `latitude` | `double?` | Optional | Geo-latitude coordinate |
| `longitude` | `double?` | Optional | Geo-longitude coordinate |

### UserModel
Represents system users across roles: `customer`, `delivery`, `admin`.

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `uid` | `String` | Required | Firebase Authentication UID |
| `docId` | `String?` | Optional | Firestore Document ID |
| `name` | `String` | Required | User full name |
| `email` | `String` | Required | Email address |
| `phone` | `String` | Required | Contact phone number |
| `village` | `String` | Required | User village area |
| `role` | `String` | `"customer"` | Role: `"customer"`, `"delivery"`, `"admin"` |
| `isActive` | `bool` | Required | Admin enable/disable flag |
| `onDuty` | `bool` | `true` | Rider availability status (delivery boys) |
| `createdAt` | `DateTime` | Required | Account creation timestamp |
| `createdBy` | `String?` | Optional | Admin UID who invited/created delivery boy account |
| `addresses` | `List<AddressModel>` | `[]` | Saved customer delivery addresses |
| `avatarUrl` | `String?` | Optional | Profile picture URL |
| `vehicleDetails` | `String?` | Optional | Vehicle type/model for delivery rider |
| `vehicleNo` | `String?` | Optional | Vehicle registration number |
| `licenseNo` | `String?` | Optional | Driver license number |
| `fcmTokens` | `List<String>` | `[]` | FCM registration tokens for device push notifications |
| `favoriteProductIds` | `List<String>` | `[]` | List of favorited product IDs |
| `notificationsEnabled` | `bool` | `true` | Customer notification opt-in toggle |

---

## 2. Product Model

Defined in: `lib/domain/entities/product.dart`

Represents catalog items with inventory control fields.

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `id` | `String` | Required | Unique Product ID |
| `name` | `String` | Required | Product title |
| `description` | `String` | Required | Product description |
| `price` | `double` | Required | Selling price (in INR) |
| `imageUrl` | `String` | Required | Product image asset URL |
| `category` | `String` | Required | Category name (e.g., Dairy & Eggs, Fruits) |
| `stock` | `int` | Required | Legacy total stock fallback |
| `unit` | `String` | Required | Quantity unit (e.g., 1 kg, 1 L, 12 pcs) |
| `requiresPrescription` | `bool` | `false` | Rx prescription requirement flag |
| `physicalStock` | `int` | Computed/Stock | Total physical stock on hand |
| `reservedStock` | `int` | Computed/0 | Stock reserved by ongoing orders |
| `availableStock` | `int` | `physicalStock - reservedStock` | Available stock ready for purchase |
| `lowStockThreshold` | `int` | `10` | Reorder alert threshold |

---

## 3. Order & OrderItem Models

Defined in: `lib/domain/entities/order.dart`

### OrderItem
Represents an individual item purchased within an order snapshot.

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `productId` | `String` | Required | Referenced Product ID |
| `name` | `String` | Required | Product name at time of order |
| `price` | `double` | Required | Unit price at time of order |
| `quantity` | `int` | Required | Purchased quantity |

### Order
Represents customer purchase transactions and delivery state machine.

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `id` | `String` | Required | Order ID |
| `customerId` | `String` | Required | Customer User UID |
| `customerName` | `String` | Required | Customer name |
| `customerPhone` | `String` | Required | Customer phone number |
| `deliveryAddress` | `String` | Required | Formatted delivery address text |
| `village` | `String` | Required | Destination village |
| `latitude` | `double?` | Optional | Destination geo-latitude |
| `longitude` | `double?` | Optional | Destination geo-longitude |
| `items` | `List<OrderItem>` | Required | Purchased line items |
| `totalAmount` | `double` | Required | Total payable amount |
| `paymentMethod` | `String` | Required | Payment method (e.g., COD, UPI) |
| `status` | `String` | Required | Order state (`pending`, `assigned`, `delivered`, etc.) |
| `deliveryBoyId` | `String?` | Optional | Assigned rider UID |
| `deliveryBoyName` | `String?` | Optional | Assigned rider name |
| `deliveryBoyPhone` | `String?` | Optional | Assigned rider phone |
| `createdAt` | `DateTime` | Required | Timestamp when order was placed |
| `updatedAt` | `DateTime` | Required | Last state change timestamp |
| `rating` | `int?` | Optional | Customer rating (1 to 5 stars) |
| `ratingComment` | `String?` | Optional | Feedback comment |
| `notifyTier` | `int?` | Optional | Delivery notification escalation tier |

---

## 4. Inventory Ledger Model

Defined in: `lib/domain/entities/inventory_ledger.dart`

Tracks double-entry inventory audit records (`/inventoryLogs` collection).

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `id` | `String` | Required | Audit log ID |
| `productId` | `String` | Required | Referenced Product ID |
| `adminId` | `String` | Required | Admin UID or `'system'` |
| `orderId` | `String?` | Optional | Associated Order ID if sale/return |
| `changeType` | `String` | Required | Change type (`restock`, `sale`, `spoilage`, `adjustment`, `return`) |
| `physicalDelta` | `int` | Required | Change in physical stock level |
| `reservedDelta` | `int` | Required | Change in reserved stock level |
| `notes` | `String` | Required | Reason / notes for adjustment |
| `timestamp` | `DateTime` | Required | Audit entry timestamp |

---

## 5. App Config Model

Defined in: `lib/domain/entities/app_config.dart`

Represents dynamic operational configuration stored in `/config/app`.

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `storeOpen` | `bool` | Required | App-wide checkout enable/disable switch |
| `deliveryFee` | `double` | Required | Base delivery fee charged to customers |
| `freeDeliveryAbove` | `double` | Required | Minimum order total for zero delivery fee |
| `updatedAt` | `DateTime` | Required | Configuration update timestamp |
| `etaLabel` | `String?` | Optional | Delivery promise badge (e.g. `"Delivers in ~20 min"`) |
| `riderPayoutPerDelivery` | `double` | `30.0` | Flat rider compensation per completed order |
| `supportPhone` | `String?` | Optional | Support phone hotline |
| `supportWhatsapp` | `String?` | Optional | Support WhatsApp contact number |
| `categories` | `List<String>` | `[]` | Dynamic category list for customer app |

---

## 6. Banner Item Model

Defined in: `lib/domain/entities/banner_item.dart`

Represents promotional banners displayed on customer home screen (`/banners` collection).

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `id` | `String` | Required | Banner ID |
| `imageUrl` | `String` | Required | Banner image URL |
| `category` | `String?` | Optional | Target category filter when tapped |
| `isActive` | `bool` | Required | Visibility toggle |
| `sortOrder` | `int` | Required | Display ordering weight |
| `createdAt` | `DateTime` | Required | Creation timestamp |

---

## 7. Dashboard Stats Model

Defined in: `lib/domain/entities/dashboard_stats.dart`

Represents administrative metric aggregates for the admin home dashboard.

| Field | Type | Required / Default | Description |
|---|---|---|---|
| `activeOrdersCount` | `int` | Required | Number of ongoing active orders |
| `activeRidersCount` | `int` | Required | Number of currently active/on-duty riders |
| `completedRevenue` | `double` | Required | Total revenue from completed orders |
| `productCount` | `int` | Required | Total active catalog products count |
| `lastUpdated` | `DateTime` | Required | Stats generation timestamp |
