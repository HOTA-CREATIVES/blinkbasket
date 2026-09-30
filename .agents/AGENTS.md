# JC Mart Developer Rules & Grounded Context

This file defines the project-wide development rules, clean architecture guidelines, design standards, and constraints for the JC Mart Hyperlocal Commerce Platform.

## 1. Clean Architecture Guidelines

Maintain strict separation of concerns across the following layers:
- **UI Layer** (screens/widgets): Located in [lib/modules/](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/modules/). Screens should only consume state and dispatch actions via Providers. They must not contain business logic or call Firebase directly.
- **Provider/State Layer**: Located in [lib/core/providers/](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/core/providers/). Manages UI state, consumes use cases/repositories, and notifies listeners.
- **Use Case/Domain Layer**: Located in [lib/domain/](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/domain/). Houses pure business logic, entities ([lib/domain/entities/](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/domain/entities/)), and abstract repository interfaces ([lib/domain/repositories/](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/domain/repositories/)).
- **Repository/Data Layer**: Located in [lib/data/](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/data/) and [lib/core/services/](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/core/services/). Implements the repository interfaces, handles DTOs (e.g., `ProductDto`, `OrderDto`), and talks to external services like Firebase/Firestore.

*Rule*: All data access must route through a defined repository interface. Do not invoke Firebase/Firestore directly in state providers or UI widgets.

## 2. Coding Standards & Best Practices

- **Constructor Usage**: Prefer `const` constructors wherever possible.
- **Imports**: Eliminate unused imports. Use relative paths within feature modules and clean exports.
- **Asynchronous Code**: Ensure proper use of `async`/`await`. Avoid passing `BuildContext` across asynchronous gaps.
- **Exception Handling**: Wrap all repository network and database operations (Firebase, Cloud Functions, External REST APIs) in `try-catch` blocks. Return structured result wrappers (e.g., `Result<T>`) rather than throwing uncaught exceptions to the UI.
- **Null Safety**: Avoid force-unwrap operators (`!`) unless absolutely necessary and logically guaranteed to be non-null. Always use optional chaining or fallback values.

## 3. Core Domain & Business Rules

### Inventory Sync & Stock Control
- Maintain the stock formula:
  $$\text{availableStock} = \text{physicalStock} - \text{reservedStock}$$
- Any direct stock modification must update all three fields synchronously.
- **Double-Entry Ledger Integrity**: Every stock adjustment (physical or reserved) must generate an entry in the `/inventoryLogs` collection. The log must document `productId`, `adminId` (or `system`), `changeType` (e.g., `restock`, `sale`, `return`, `correction`), `physicalDelta`, `reservedDelta`, `notes`, and `timestamp`.
- **Transaction Isolation**: Updates to stock levels must run inside a Firestore Transaction (`runTransaction`) to prevent race conditions during concurrent checkouts.

### Catalog Integrity
- **Access Controls**: Only users with the `admin` custom claim (`request.auth.token.admin == true`) can write to the `/products` and `/config` collections.
- **Price Modifiers**: Price modifications must be restricted to admin-only screens. Pricing input must be strictly positive (`> 0.0`).
- **Store Status**: All checkout operations must check if the store is open (`storeOpen == true` in `/config/app`) before processing.

## 4. UI/UX Design System & Aesthetics

- **Typography & Colors**: Use tokens defined in [app_tokens.dart](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/core/design/app_tokens.dart) and themes in [app_theme.dart](file:///c:/Users/gurun/Documents/PROJECTS/hota-projects/hypermart/lib/core/theme/app_theme.dart). Do not hardcode colors or spacing.
- **Premium Animations**:
  - **Swipe-to-Confirm Slider**: Used for rider task updates. Dragging an icon along a path with spring-back animation if released early.
  - **Auto-Focus OTP Input Grid**: Auto-spaced 4-digit input with vibration and shake animations on error.
  - **Shimmer Placeholders**: Render grey-to-white gradient skeletons matching target card dimensions during loading.
  - **Parallax Header**: Use parallax image scaling on profiles and product detail screens.
