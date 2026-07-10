# API & Contract Reference - BlinkBasket

BlinkBasket uses Firebase Firestore as its backend database and coordinates CRUD calls via repository abstractions instead of direct REST endpoints.

---

## 1. Catalog Products Repo (`ProductRepository`)

### Stream Catalog
*   **Method:** `Stream<List<Product>> streamProducts()`
*   **Path:** Firestore Collection `/products`

### Add Item
*   **Method:** `Future<void> addProduct(Product product)`
*   **Payload:** DTO map mapping model definitions.

---

## 2. Order Pipelines Repo (`OrderRepository`)

### Stream Customer Orders
*   **Method:** `Stream<List<Order>> streamCustomerOrders(String customerId)`
*   **Path:** Collection `/orders` queried by `customerId`.

### Stream Rider Tasks
*   **Method:** `Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId)`
*   **Path:** Collection `/orders` queried by `deliveryBoyId`.

### Stream All Orders
*   **Method:** `Stream<List<Order>> streamAllOrders()`
*   **Path:** Collection `/orders` sorted by `createdAt` descending.

### Create Order
*   **Method:** `Future<bool> placeOrder(Order order)`
*   **Transaction:** Batch sets the order document while decrementing item stocks.
