---
name: Inventory Sync & Stock Control
description: Audits the stock reservation system, double-entry inventory ledger logging, and transactional safety.
---

# Inventory Sync & Stock Control Skill

This skill is active when reviewing stock adjustments and transaction safety.

1. **Stock Formula Consistency**:
   - Ensure the relationship holds in all repositories and services:
     $$\text{availableStock} = \text{physicalStock} - \text{reservedStock}$$
   - Direct stock modifications must update all three fields synchronously.

2. **Double-Entry Ledger Integrity**:
   - Every stock adjustment (physical or reserved) must generate an entry in the `/inventoryLogs` collection.
   - Logs must document `productId`, `adminId` (or `system`), `changeType` (e.g. `restock`, `sale`, `return`, `correction`), `physicalDelta`, `reservedDelta`, `notes`, and `timestamp`.

3. **Transaction Isolation**:
   - Updates to stock levels must run inside a Firestore Transaction (`runTransaction`) to prevent race conditions during concurrent checkouts.
