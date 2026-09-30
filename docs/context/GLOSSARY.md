# Glossary

## Purpose
Shared vocabulary — domain terms, status values, and project-internal names with their exact meanings.

## Key facts

### Domain terms
| Term | Meaning |
|---|---|
| **COD** | Cash on Delivery — the only payment method (`paymentMethod: "COD"` hardcoded; no gateway by design) |
| **Broadcast** | Notifying on-duty riders about a pending order (push); orders are visible to any on-duty rider per rules, push priority is tiered |
| **Claim / Accept** | Rider reserving a pending order via `acceptOrder` (transactional first-wins) |
| **Notify tier (1/2)** | Tier 1 = on-duty riders matched to the order's village; tier 2 = all on-duty riders. `escalateStaleOrders` promotes tier 1 → 2 after 90 s and re-pings forever |
| **Escalator** | `escalateStaleOrders` scheduled function (every 1 min) |
| **Expiry** | `expireStaleOrders` auto-cancels pending+unassigned orders after 24 h (`cancelReason: "auto_expired"`) |
| **Reservation** | Stock moved from `availableStock` into `reservedStock` at checkout; released on cancel/expiry; converted to a sale at OTP verification |
| **Ledger** | `/inventoryLogs` — append-only audit of every stock delta with actor attribution |
| **Duty vs Active (rider)** | `onDuty` = rider's own availability toggle; `isActive` = admin's enable/disable; `isDeleted` = soft delete. All three coexist on `deliveryBoys` |
| **UID-locking** | Riders can't migrate docs; `deliveryBoys` doc ID must equal the rider's auth UID (provisioned by `createRiderLogin`) |
| **Role discovery** | Client resolving which persona a signed-in account is, by checking `admins` → `deliveryBoys` → `users` |
| **Onboarding gate** | Customers must complete name/phone/village (`onboardingCompleted`) before entering the shop |
| **Biometric gate** | Admin console locked behind `local_auth` (biometric/PIN) on launch and on app resume |
| **Biometric reveal** | Customer OTP display gated behind `local_auth` confirmation |
| **Geofence** | 12 km radius check from the nearest of 5 village centroids; coordinates are mandatory |
| **Village** | Service-area unit (Bhimavaram, Veeravasaram, Rayakuduru, Srungavruksham, Mentada); duplicated in Dart + TS deliberately |
| **Whitelist** | The `admins` / `deliveryBoys` collections acting as role allowlists |

### Order status vocabulary
`pending → assigned → picked_up → out_for_delivery → delivered` (+ `cancelled` from pending/assigned/out_for_delivery). `delivered` is reachable **only** through `verifyDeliveryOtp`.

### Ledger changeType vocabulary (as written today)
`reserve` (placeOrder), `sale` (verifyDeliveryOtp), `return` (cancellation release), `restock` (product creation / admin adjust), plus admin free-form types via `adjustStock`. Entity constant declares `kActorAdmin` etc.; `actorType` ∈ `customer | rider | admin | system`.

### Legacy names (naming drift)
| Legacy | Current |
|---|---|
| BlinkBasket / `blinkbasket` | J C Mart (GitHub URLs in package.json still say blinkbasket) |
| HyperMart / JP Mart | J C Mart (docs use three names) |
| `adminId` (ledger) | `actorId` (client) — bridged in DTO |

### Roles & claims
| Role | Custom claim | Collection |
|---|---|---|
| Customer | none | `users/{uid}` |
| Delivery | `{role:"delivery", delivery:true}` | `deliveryBoys/{uid}` |
| Admin | `{role:"admin", admin:true}` | `admins/{uid}` |

## Open questions / unknowns
- Official product name for store listing ("J C Mart" is the app title in manifests/web; pick one and sweep the docs).
- `EarningsScreen` payout math (`riderPayoutPerDelivery`) — confirm whether "payout" is per delivery or includes COD reconciliation semantics.
