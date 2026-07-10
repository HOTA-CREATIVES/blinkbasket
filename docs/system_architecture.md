# System Architecture Document - BlinkBasket

This document defines the high-level architecture of the BlinkBasket quick-commerce platform.

---

## 1. Clean Architecture Overview
The application code is divided into three distinct layers to enforce separation of concerns:

```text
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│         (Screens, Widgets, Cart & Order Providers)      │
└───────────────────────────┬────────────────────────────┘
                            │ Consumes
┌───────────────────────────▼────────────────────────────┐
│                      Domain Layer                      │
│     (Business Entities, Repositories Contracts,        │
│                    Use Case classes)                   │
└───────────────────────────┬────────────────────────────┘
                            │ Implemented By
┌───────────────────────────▼────────────────────────────┐
│                       Data Layer                       │
│    (Repositories Implementations, Data Sources, DTOs)  │
└────────────────────────────────────────────────────────┘
```

*   **Domain Layer:** Core Dart business logic containing `Product` and `Order` entities, abstract repository interfaces, and use cases.
*   **Data Layer:** Concrete repository implementations. Contains DTO models (`ProductDto`, `OrderDto`) and maps database structures.
*   **Presentation Layer:** State provider controllers (`AuthProvider`, `CartProvider`, `OrderProvider`) and UI screen widgets.

---

## 2. Infrastructure Patterns
*   **Reactive Stream Listeners:** All client applications query database views through real-time Firestore listeners. Any write operation on `/orders/{id}` instantly pushes new snapshot models to the customer, delivery rider, and admin consoles.
*   **Atomic Transactions:** Stock balance values are adjusted using batch sets (`WriteBatch`) inside the repository implementation to ensure consistency when placing orders.
