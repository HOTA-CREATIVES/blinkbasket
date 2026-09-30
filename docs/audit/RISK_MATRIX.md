# Risk Matrix

## Purpose
Visual prioritization of the audit findings by likelihood × impact, with the risk-acceptance status of each.

## Heat map

Likelihood: **L**ow / **M**edium / **H**igh that the risk materializes if unaddressed.

| Impact → / Likelihood ↓ | Low | Medium | High |
|---|---|---|---|
| **High** | | M-2 release identity (`com.example.*` rejected or accidental debug-signed publish) | M-7 stale security docs drive wrong operator actions · H-1 split audit trail breaks COD reconciliation tooling as it's built |
| **Medium** | L-2 licensing ambiguity · L-6 debug logs | M-4 deploy no-op (prod drift) · M-5 unbounded collections (cost creep) · M-6 wrong conventions for agents/new devs | M-3 no provider/use-case tests (regressions ship green) |
| **Low** | L-4 dead screen · L-5 seed sprawl · I-1 README links · I-6 version drift | I-2 dead backend branch · I-5 rules not truly tested | L-3 approximate rate limiting under autoscaling · I-4 stream caps truncate history |

**Read:** everything High-impact clusters in the "act this month" band; the Medium/High cell (M-3, test debt) is the slowest to fix and the most likely to bite as the codebase grows.

## Register with acceptance status

| ID | Risk statement | L | I | Treatment |
|---|---|---|---|---|
| M-2 | Publishing under `com.example.hypermart` is impossible; if a "release" build is produced before the keystore exists it signs with debug keys | H | H | **Mitigate now** (A1) — irreversible if hit |
| M-7 | An operator or agent follows stale docs (e.g. "no App Check", "no floor guard") and makes wrong changes or distrusts the system | H | H | **Mitigate now** (A4) — cheap |
| H-1 | Half of ledger entries keyed `adminId`, half `actorId`; reconciliation/BI silently drops entries | H | H | **Mitigate now** (A3) — S effort |
| M-3 | Business-logic regressions (auth role flips, cart math) reach production with CI green | H | M→H | **Mitigate** (B1) starting immediately; accept interim risk consciously |
| M-4 | Team believes main-push = deployed; production lags until a manual deploy | M | M→H | **Mitigate** (A2) |
| M-5 | `inventoryLogs`/support messages grow unbounded; cost + latency creep | M | M | **Mitigate** (B3) |
| M-6 | Agents/contributors implement Riverpod/Freezed patterns against a Provider codebase | M | M | **Mitigate** (A4) |
| M-1 | 1,985-line admin screen slows every future change | M | M | **Mitigate** (B4, phased) |
| L-1 | Public product read leaks pricing pre-login | M | L | **Accept** if pre-login browse is a product requirement; else tighten (B5 adjacent) |
| L-2 | Licensing ambiguity for contributors | L | L | **Mitigate** (B5) — trivial |
| L-3 | Rate limit bypassed under multi-instance scaling or reset gaps | M | L | **Accept for launch**; revisit (C4) |
| L-4/L-5/L-6 | Dead screen / seed sprawl / local logs | M | L | **Clean up** (A6) |
| I-2 | Dead backend branch confuses future architects | M | L | **Clean up** (C2) |
| I-5 | Rules regressions undetected by CI | M | M | **Mitigate** (B2) |
| I-4 | Fixed stream caps silently truncate history at scale | M (at scale) | M | **Watch**; trigger = order count nearing 300 |
| I-1/I-6 | Broken README links; SDK version drift | H (links) | L | **Clean up** (A4) / document (A4) |

## Top risks if you do nothing else (narrative)
1. **You cannot ship to Play** under the current applicationId — and once anything is published under a wrong-but-acceptable ID you can never change it. Decide today (M-2).
2. **Your audit trail is half-renamed.** The moment anyone builds COD reconciliation or taxation exports from `inventoryLogs`, half the actor data disappears depending on which key they filter (H-1).
3. **Your docs lie about your security posture** — in both directions (claiming missing things that exist, and omitting real gaps). The next audit, agent, or contributor starts from false premises (M-7/M-6).
4. **Your CI says "deployed" when it isn't** — production functions/rules drift from main silently (M-4).
5. **Your fastest-moving code (client business logic) is your least-tested** — the safety net covers models and the server, not the glue (M-3).

## Risk appetite notes
- For a village-scale COD pilot, **accepting** L-3 (in-memory rate limiting) and deferring C4 is reasonable; App Check already blunts the abuse vector.
- **Not acceptable:** anything in the High-impact row past 30 days, and any publish attempt before A1 completes.
