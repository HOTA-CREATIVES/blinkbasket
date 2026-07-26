# Live Rider Tracking — Feature Spec & Quotation

Prepared 2026-07-19 for J C Mart / hypermart. Replaces the current static-pin, manual-refresh order tracker with a Blinkit-style live-moving rider marker.

## Current state (verified against shipped code)

- **Customer side** — `lib/modules/customer/screens/order_tracking_screen.dart` shows a static delivery pin (set once at checkout) and a status-step timeline (`pending → assigned → picked_up → out_for_delivery → delivered`). The "arriving in Xm" line is a client-side countdown from an admin-typed ETA string, not derived from anything real-time.
- **Rider side** — `lib/modules/delivery/screens/rider_map_screen.dart` plots the rider's own active-order destinations as static pins on a Leaflet map. `task_detail_screen.dart`'s NAVIGATE button hands off to the external Google/Apple Maps app for turn-by-turn.
- **No live position anywhere** — `geolocator` is already a dependency, but only used once, to drop the delivery pin at checkout. No continuous position stream exists in either app today.

## Proposed architecture

Rider device streams position while `out_for_delivery`; Firestore fans it out to the one customer watching that order. No new backend service — this stays inside the existing Firebase project.

```
Rider app                    Firestore                      Customer app
Geolocator stream    →     riderLocations/{orderId}    →   .snapshots() + animated marker
(throttled, foreground-      (new collection —              (order_tracking_screen.dart)
 service notification          not deliveryBoys)
 on Android)
                                    ↑
                        scheduled function, reuses
                        escalateStaleOrders's cadence
                        pattern, purges docs once order
                        leaves out_for_delivery
```

### Why a new collection, not a field on `deliveryBoys`

`onRiderWritten` (in `functions/src/index.ts`) fires on *every* write to a rider's document — cheap today because writes are rare (onDuty toggles, profile edits). A location update every 8-10 seconds during an active delivery would fire that trigger thousands of times a day for no reason and risk tripping its claims-sync logic. A dedicated `riderLocations` collection keeps location writes outside that trigger entirely, and lets its security rule be scoped tightly: write access only to the assigned rider, read access only to that order's customer — narrower than `deliveryBoys`' existing rule.

### Why not a real routing API on day one

The existing `haversineMeters` helper in `functions/src/index.ts` already computes straight-line distance for service-area checks. Reusing it for a straight-line ETA (distance ÷ an assumed local average speed) costs nothing extra and is honest about its own imprecision. Swapping in a real road-routing ETA (Google Routes API or OSRM) is a clean drop-in later — scoped as an optional add-on below, not part of the core build.

## Data model & rules changes

| Path | Field | Written by | Notes |
|---|---|---|---|
| `riderLocations/{orderId}` | `lat`, `lng` | Rider app | overwritten in place, not appended — one doc per active delivery |
| | `heading` | Rider app | optional, for a rotated marker icon |
| | `updatedAt` | Rider app | server timestamp; customer UI treats >60s stale as "signal lost" |
| | `riderId` | Rider app | redundant with the order's own `deliveryBoyId`, used by the rule to authorize the write |

New rule (additive — nothing existing changes):

```
match /riderLocations/{orderId} {
  allow read: if get(/databases/$(database)/documents/orders/$(orderId)).data.customerId == request.auth.uid;
  allow write: if get(/databases/$(database)/documents/orders/$(orderId)).data.deliveryBoyId == request.auth.uid
    && get(/databases/$(database)/documents/orders/$(orderId)).data.status == 'out_for_delivery';
}
```

## Platform & store-policy considerations

The part of this feature that isn't really engineering effort so much as waiting: background location on both stores is a reviewed, disclosure-gated capability.

- **Android** — Background location while backgrounded requires a foreground service with a persistent notification (`geolocator` 14.x supports this natively — no new dependency) *and* a completed Play Console Data Safety declaration. Google's review for `ACCESS_BACKGROUND_LOCATION` specifically can add its own review cycle beyond the normal release rollout — budget days, not hours.
- **iOS** — Needs `NSLocationWhenInUseUsageDescription` at minimum. Continuing to track with the screen off mid-delivery needs "Always" authorization plus the `location` background mode — App Store review holds these to a materially higher bar than Android.

**Recommended v1 scope:** foreground-only tracking (screen on, app open) for both platforms. Matches the Blinkit-style customer experience without the background-location review risk. Background tracking is scoped as an optional phase below.

## Effort breakdown

One mid-to-senior Flutter+Firebase developer, sequential. Hours are engineering time; store-review wait is elapsed time, not billable effort.

| Phase | Deliverable | Hours |
|---|---|---:|
| Schema & rules | `riderLocations` collection, security rules, TTL/cleanup scheduled function | 10 |
| Rider app | Foreground location stream, distance-filtered writes (~25m or 10s), start/stop tied to order status | 10 |
| Customer app | Live map on `order_tracking_screen.dart`: animated marker interpolation, "signal lost" state, recenter control | 10 |
| ETA | Haversine-based live ETA replacing the static countdown | 4 |
| Store compliance | Android Data Safety form, iOS usage-description copy, privacy policy update | 5 |
| QA | Multi-device pass: killed/backgrounded app, poor connectivity, permission-denied paths, both personas | 8 |
| **Core build total** | | **47 h** |

### Optional add-ons (priced separately)

| Add-on | Why you'd want it | Hours |
|---|---|---:|
| Background tracking (screen-off) | Rider marker keeps moving if the rider locks their phone mid-delivery | +8 |
| Real road-distance ETA | Routing API instead of straight-line — accurate around Bhimavaram's actual road network | +6 |
| Route polyline on customer map | Draws the rider's path, not just a dot | +5 |

## Quotation

Two commonly-seen India-market rate bands for the 47-hour core build — reference points, not a fixed price. Actual cost is hours × your real rate.

| Tier | Core (47h) | Rate assumption |
|---|---|---|
| Independent / freelance | ₹42,000–₹66,000 | ≈ ₹900–1,400/hr ($500–790) |
| Boutique studio / agency | ₹1,10,000–₹1,85,000 | ≈ ₹2,350–3,950/hr ($1,320–2,220) |

| | Core (47h) | + Background | + Real routing | + Polyline | All-in (66h) |
|---|---:|---:|---:|---:|---:|
| Freelance @ ₹1,100/hr | ₹51,700 | ₹8,800 | ₹6,600 | ₹5,500 | ₹72,600 |
| Agency @ ₹3,000/hr | ₹1,41,000 | ₹24,000 | ₹18,000 | ₹15,000 | ₹1,98,000 |

**Ongoing infra cost:** a location write every ~10s for a 20-minute delivery is ~120 writes; the customer's live screen reads similarly. At Firestore's pay-as-you-go pricing this is fractions of a rupee per order even at hundreds of daily orders. The optional routing-API add-on has a real per-call cost instead (~$5 per 1,000 requests) if taken.

## Delivery timeline

| Day | Milestone |
|---|---|
| 1–2 | Schema, rules, cleanup function — backend foundation, testable in isolation via emulator |
| 2–4 | Rider app streaming — location capture wired to order status transitions |
| 4–6 | Customer live map + ETA — the visible payoff |
| 6–7 | Store-compliance paperwork (can run in parallel with days 4–6) |
| 7–8 | QA pass & ship |

~7-8 working days of engineering. Add unpredictable store-review latency on top before it's live for every user.

## Assumptions & exclusions

- Assumes the existing Firebase Blaze plan, Cloud Functions deployment, and CI stay as-is — no infra migration bundled in.
- Assumes rider devices have GPS + a working mobile data connection during delivery; no offline-queue-and-replay for location pings in v1.
- Excludes redesigning the rider-side map (`rider_map_screen.dart`) to show the rider's own live position to themselves — this spec is customer-facing only.
- Excludes historical route storage/replay for support/dispute resolution — `riderLocations` is designed to be ephemeral (cleaned up after delivery), not an audit trail.
- Google/Apple review timelines are outside anyone's control and aren't included in the hour totals above.
