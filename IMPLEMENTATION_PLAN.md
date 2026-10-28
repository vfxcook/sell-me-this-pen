# Implementation Plan — Sell Me This Pen

Phases follow PRD §18. The governing rule, from the commissioning
message, is: **complete and test one phase before beginning the next,
and do not begin building all the Flutter screens until the simulation
proof of concept succeeds.** Phase 0 has not succeeded yet, so this
plan starts with finishing Phase 0 and gates everything else on it.

## User decision 2026-10-28 — build now, keys later (supersedes the gate above for sequencing only)

Frame: "These we can set later, lets do the implementation, use 3
options to switch in settings then fill keys in settings."
Implemented as: Settings screen with exactly 3 engine options —
`mirofish` (needs LLM + Zep keys), `direct` (needs LLM key only, no
Zep), `demo` (labelled sample, no keys, default so the app is
explorable). Key fields in Settings: LLM API key, LLM base URL, LLM
model name, Zep API key. Keys are stored server-side encrypted
(Fernet), returned only masked, never in the app build, never logged.
This does NOT change the honesty rule: with no keys set, a
mirofish/direct run fails with ENGINE_NOT_CONFIGURED; demo output is
always flagged is_demo with a DEMO banner. The Phase 0 live-MiroFish
run remains outstanding and is still required before any claim that
a production simulation ran.

## Phase 0 — Technical Discovery [IN PROGRESS, NOT PASSED]

Delivered this session:
- `MIROFISH_AUDIT.md` — licence, interfaces, dependencies, model
  requirements, programmatic invocation, capability matrix, blockers.
- `ARCHITECTURE.md` — adapter-based design (this plan's companion).
- `poc/run_poc.py` + `poc/poc_log.txt` — reproducible PoC attempt.

Remaining, in order:
1. **B1+B2 — credentials.** Obtain an OpenAI-compatible LLM key and a
   Zep Cloud key through the secure entry flow (never in chat).
   Suggested first run: the cheapest/smallest model the provider
   offers, one platform only, `max_rounds` small.
2. **Install.** `uv` install (or `pip install -r
   backend/requirements.txt` — background attempt already running;
   see `poc/full_install.log`), then boot MiroFish and confirm
   `GET /health` → `{"status": "ok"}`.
3. **Official-example smoke test.** Run the documented flow by hand
   against a tiny seed file: ontology → graph build → create →
   prepare → start → poll actions/posts → stop → report. Record every
   request/response shape actually observed (they become the adapter
   contract tests).
4. **Minimal PoC program.** A script (not the method skill, not
   hand-written dialogue) that submits one product idea through the
   adapter path — seed brief + requirement — and prints the first
   real engine events with their MiroFish IDs. This is the exit
   artefact: `poc/poc_success.json` containing real `simulation_id`,
   `actual_agent_count`, and event samples.
5. **Benchmark (small/medium).** Measure, for at least two sizes:
   wall time per phase, peak memory, LLM tokens + cost, agent count
   actually produced, events per round, failure modes. Only then
   define Quick/Standard/Deep and credit costs.
6. **Legal note.** AGPL review (audit §1) — at minimum a written
   decision: comply-and-publish vs seek commercial licence vs
   replace engine. Blocks public launch, not the PoC.

Exit criterion (PRD, verbatim intent): a genuine MiroFish simulation
runs and its output is retrieved programmatically. **Until then, Phase
1 does not start.**

## Phase 1 — Flutter UI [GATED — DO NOT START EARLY]

Prerequisites: Phase 0 exit + Flutter/Dart toolchain installed on the
build machine (currently absent on this VM) + mockup decision (B6:
no mockup file arrived in this chat; PRD §6.1 tokens are the fallback
design reference — dark `#06101F` / `#0B1B30`, pink `#FF008C`, blue
`#287BFF`, positive `#13DB9A`, negative `#FF527A`).

Deliverables: Flutter project (Riverpod, GoRouter, Dio), theme/design
system, navigation (bottom bar: Home / Simulations / Reports /
Profile), all 15 PRD §6.2 screens, responsive + keyboard-aware +
safe-area handling. Data source: a **separate, labelled mock provider**
for development only, behind a build flag — the production provider
is wired in Phase 3 and the mock is removed from release builds.

Tests before proceeding: widget tests, navigation tests, form
validation, golden/layout checks on two phone sizes. Exit: app runs
on an emulator/device with mock data, zero production claims.

## Phase 2 — Backend Foundation [after Phase 1]

FastAPI project (`/api/v1`, PRD §9), PostgreSQL schema + migrations
(PRD §10 + `engine_runs` trace table), Supabase Auth validation,
idea/audience CRUD with ownership checks, simulation job system
(Redis queue + worker skeleton, idempotency keys), Docker Compose
(product backend + Postgres + Redis; MiroFish as a separate service),
OpenAPI docs. No MiroFish calls yet except through the adapter
interface with a stub that returns a clear "engine unavailable"
error — never fake events.

Tests: API contract, auth, authorisation (cross-user access denied),
idempotency (same key = one job), migration up/down. Exit: all tests
pass; API serves ideas/audiences end to end.

## Phase 3 — MiroFish Integration [the real engine lands]

Deliverables: `MiroFishAdapter` implementing the interface in
`ARCHITECTURE.md` §4–§5, event normalisation, status mapping,
cancellation, timeouts, partial-result preservation, failure
recovery, benchmark results from Phase 0 re-run through the adapter.

Tests (PRD §17.3): official-example smoke via adapter, small +
medium benchmark, event normalisation, partial failure, timeout,
concurrent jobs (queue fairness), token/cost measurement. Exit: a
real idea submitted in the app returns real engine events in the
live feed, persisted in PostgreSQL, visible after app restart.

## Phase 4 — Analysis and Reporting

Classifier + theme/objection/question extraction with denominators
and methods recorded; results dashboard; report generation (PDF +
share link, private by default); idea revision + versioning;
side-by-side comparison with a warning when audiences/settings
differ. Every report carries the §11.3 disclaimer and engine/method
metadata. Tests: classifier accuracy spot-checks against labelled
engine events, report content checks, comparison edge cases.

## Phase 5 — Commercial Features

Credit ledger (atomic reserve/settle/refund, failed-job refunds),
subscription entitlements, Google Play Billing for in-app digital
purchases (PRD §13.3 — no web-checkout shortcut assumed), usage
limits, billing history, account management (sign-out, deletion with
data-deletion procedure). Tests: credit accounting (incl. double-
charge prevention on retries), entitlement gating (guest cannot run
paid sims), Play Billing verification mocks. Secrets audit: grep the
APK build for keys before any release.

## Phase 6 — QA and Android Release

Automated suites green, integration + end-to-end test per PRD §17.4
(sign-in → idea → audience → queue → genuine engine run → persisted
events in app → analysis → saved report → revise → rerun), security
review (auth, isolation, no exposed MiroFish, no secrets in APK),
performance review (cold start <3s target, API p95 <800ms excluding
simulations), signed APK + AAB, install verified on a physical
Android device, deployment documentation updated. Definition of Done
is PRD §20, all boxes, including the licence item.

## Project layout (PRD §19, as built)

```
sell-me-this-pen/
  MIROFISH_AUDIT.md  ARCHITECTURE.md  IMPLEMENTATION_PLAN.md
  README.md
  poc/  (run_poc.py, poc_log.txt, full_install.log, .venv/ — dev only)
  apps/mobile/        (Phase 1)
  services/api/       (Phase 2)
  services/worker/    (Phase 2–3, incl. engines/mirofish.py)
  packages/api-contracts/
  infrastructure/     (docker, migrations, deployment)
  docs/               (PRD.md, API.md, DEPLOYMENT.md, TESTING.md)
```

## Risks and fallbacks

- If B1/B2 cannot be supplied: Phase 0 stays failed; do not fake it.
  Fallback to propose: a purpose-built multi-agent adapter over a
  configurable provider (same product interface, same app), with
  MiroFish retained as method reference only. This changes the engine,
  not the product.
- If benchmarks show MiroFish too slow/costly for mobile price
  points: shrink presets (fewer rounds, one platform), add a queue
  with honest wait estimates, or revisit the engine — do not silently
  shrink agent counts while advertising them.
- If AGPL review blocks closed SaaS: publish MiroFish source as
  deployed, or seek a commercial licence, or swap engines before
  launch. Never launch first and review later.
- If the full-dependency install fails on this VM: the engine must
  run on a host that can install it (container image
  `ghcr.io/666ghj/mirofish:latest` is the documented route) — that
  deployment decision belongs to Phase 2, with costs checked first.
