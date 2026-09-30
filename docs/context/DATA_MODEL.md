# Data Model

## Purpose
Firestore collections, their schemas as actually written by code, and who writes what. Field lists come from DTOs and writer code, not aspirational docs.

## Key facts

### Collections
| Collection | Doc ID | Written by | Notes |
|---|---|---|---|
| `users/{uid}` | auth UID | client (field-allowlisted), rules [firestore.rules:32-51](../../firestore.rules#L32-L51) | role=`customer`; addresses embedded; cart map; loyalty fields server-only |
| `admins/{uid}` | auth UID (must equal UID) | **nobody from client — `write: if false`**; console only | triggers sync `admin` claim |
| `deliveryBoys/{uid}` | auth UID | `createRiderLogin` CF (create), admin client (update), rider self-update (allowlisted fields) | soft delete via `isDeleted` |
| `products/{id}` | auto | admin client (CRUD), CFs (stock) | price>0 enforced in rules; 4-field stock model + legacy `stock` |
| `orders/{id}` | auto | **create/delete: `if false`** — `placeOrder` CF (create) via Admin SDK | status machine enforced by rules |
| `orders/{id}/private/delivery` | `delivery` | `placeOrder` (create), `verifyDeliveryOtp` (attempts), `resetOtpAttempts` (admin reset) | OTP readable only by ordering customer |
| `config/app` | fixed | admin client (Store settings) | storeOpen, fees, ETA, categories, support numbers |
| `config/dashboard_stats` | fixed | trigger CFs (set+merge, self-healing) | counters: activeOrdersCount, activeRidersCount, completedRevenue, productCount |
| `inventoryLogs/{id}` | auto | CFs (`adminId`+`actorType`), client `adjustStock` (`actorId`+`actorType`) | **schema drift between writers** (audit H-1); rules: admin-only |
| `banners/{id}` | auto | admin client | promo carousel |
| `supportTickets/{id}` + `messages/{msgId}` | auto | customer (own), admin (all) | support module |

### Core entity fields (as serialized)

**products** ([product_dto.dart](../../lib/data/models/product_dto.dart)): `name, description, price (>0), discountedPrice?, unit, category, imageUrl, imageUrls[], stock (legacy = availableStock), physicalStock, reservedStock, availableStock, lowStockThreshold, isAvailable/isActive, isFeatured, requiresPrescription, tags[], brand, rating, reviewCount, createdAt, updatedAt`.

**orders** ([order_dto.dart](../../lib/data/models/order_dto.dart), placeOrder writer): `customerId/Name/Phone, deliveryAddress, deliveryInstructions?, village, latitude, longitude (required — geofence), items[]{productId,name,price,quantity}, subtotal, deliveryFee, totalAmount, paymentMethod:"COD", status, deliveryBoyId/Name/Phone, notifyTier, notifiedAt, stockReleased (release idempotency guard), cancelReason?, cancelledBy? (customer|rider|system), rating?, ratingComment?, ratedAt?, createdAt, updatedAt`.

**users** ([user_model.dart](../../lib/core/models/user_model.dart)): `uid, docId, name, email, phone, village, mandal?, district?, deliveryAvailable?, deliveryZoneId?, role, isActive, onDuty?, createdAt, createdBy?, addresses[AddressModel], avatarUrl?, vehicleDetails?, vehicleNo?, licenseNo?, fcmTokens[], favoriteProductIds[], notificationsEnabled, cart{}, onboardingCompleted, onboardingStep, updatedAt?`.

**inventoryLogs**: `productId, adminId|actorId, actorType (customer|rider|admin|system), orderId?, changeType, physicalDelta, reservedDelta, notes, timestamp`. Client DTO maps `actorId ?? adminId` and writes only `actorId` ([inventory_ledger_dto.dart:22,38](../../lib/data/models/inventory_ledger_dto.dart#L22)).

**appConfig**: `storeOpen, deliveryFee, freeDeliveryAbove, etaLabel?, riderPayoutPerDelivery, supportPhone?, supportWhatsapp?, categories[], updatedAt`.

**supportTicket**: `customerId/Name, subject, description, status, createdAt, updatedAt` (+ `messages` subcollection).

### Invariants
- Stock formula `availableStock = physicalStock − reservedStock`, updated transactionally everywhere; legacy `stock` kept in sync as a mirror.
- Order status machine: `pending → assigned → picked_up → out_for_delivery → delivered` (+ `cancelled` from pending/assigned/out_for_delivery via CFs); `delivered` only via `verifyDeliveryOtp`; rating write-once on delivered orders.
- `notifiedAt`/`notifyTier` exist purely for the broadcast escalator; `stockReleased: true` marks cancellation stock release done (prevents double-release on trigger replay).

### Mermaid — entity relationships
```mermaid
erDiagram
    users ||--o{ orders : places
    users ||--o{ supportTickets : opens
    users }o--|| deliveryBoys : "n/a (separate whitelists)"
    orders ||--|| private/delivery : "otp, attempts"
    orders ||--o{ inventoryLogs : "sale/return entries"
    products ||--o{ inventoryLogs : "reserve/sale/return/restock"
    products }o--o{ banners : "category link"
    admins ||--o{ deliveryBoys : provisions
    orders }o--o| deliveryBoys : "deliveryBoyId (acceptOrder)"
```

## Open questions / unknowns
- Which ledger actor key is canonical — `adminId` (functions) or `actorId` (client)? The DTO bridges both, but new readers must know to handle both (audit H-1).
- Does any reader depend on `products.isAvailable` vs `isActive`? Both appear in code; canonical name needs verification.
- No TTL/retention policy exists for `inventoryLogs` or `supportTickets/messages` — growth is unbounded (audit M-5).
- `deliveryBoys` uses both `isActive` (admin enable) and `isDeleted` (soft delete) plus `onDuty` (self toggle) — three state flags, semantics documented only in code comments.
