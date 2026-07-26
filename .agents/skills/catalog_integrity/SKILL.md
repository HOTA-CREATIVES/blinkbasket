---
name: Price & Catalog Integrity
description: Audits security access controls, price modifiers, and app-wide store state configurations.
---

# Price & Catalog Integrity Skill

This skill is active when reviewing catalog access and pricing operations.

1. **Role Access Auditing**:
   - Only users carrying the `admin` custom claim (`request.auth.token.admin == true`) can write to the `/products` and `/config` collections in Firestore.
   - Delivery riders and customers are strictly blocked from writing to these collections.

2. **Price Modification Locks**:
   - Changes to item pricing must be restricted to admin-only screens.
   - Cart managers and catalog display screens must never attempt to execute pricing modifications.

3. **Store Status Safeguards**:
   - Checkouts and order creation operations must check that the store is currently open (`storeOpen == true` in `/config/app`) before processing checkouts.
