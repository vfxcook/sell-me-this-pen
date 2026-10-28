# Architecture — Sell Me This Pen

Status: Phase 0 — design frozen pending the MiroFish PoC (see
`MIROFISH_AUDIT.md`). Nothing in this document claims a capability
that has not been verified; every MiroFish-facing statement traces to
the audit.

## 1. Principles

1. **The Flutter app never talks to MiroFish.** All simulation traffic
   goes app → Sell Me This Pen backend → adapter → MiroFish service.
   This is PRD §7.3 and also a security requirement: MiroFish has no
   auth and CORS `*` (audit §3).
2. **The engine is replaceable.** The product backend depends only on
   the `SimulationEngine` interface (§4). MiroFish is one adapter.
   If the licence decision or benchmarks force a swap, the app, API,
   database, credits, and reports do not change.
3. **No fake production data.** Mock data lives only behind an
   explicit development provider, clearly labelled, and never in a
   release build's simulation path. A failed engine run is reported
   as failed — never backfilled with invented conversation.
4. **Synthetic is labelled everywhere.** Every feed item, metric, and
   report carries: engine name + version, model identifier where
   disclosable, actual agent count, rounds, audience assumptions, and
   the PRD §11.3 disclaimer. Derived classifications are labelled
   derived, with denominators.
5. **Credits and authorisation live server-side.** The app may display
   estimates; only the backend reserves, settles, and refunds.

## 2. System diagram

```
Flutter Android app (Riverpod + GoRouter + Dio)
        │  HTTPS, Supabase JWT
        ▼
Sell Me This Pen backend — Python FastAPI  (/api/v1, PRD §9)
  ├─ Auth (Supabase token validation, per-user ownership checks)
  ├─ Ideas / Audiences / Idea versions (PostgreSQL)
  ├─ Simulations (jobs, idempotency keys, statuses)
  ├─ Events + Results + Reports (PostgreSQL + object storage)
  ├─ Analysis service (classification, themes, objections)
  ├─ Credits / Billing (atomic ledger, Play Billing verification)
  └─ Simulation adapter ──► MiroFishAdapter ──► MiroFish service
                                                        (internal only)
        │                                              Flask :5001
        │                                              OASIS workers
        ▼                                              (subprocesses)
Job queue (Redis + worker) ──► worker runs adapter calls,
polls MiroFish, persists events, runs analysis, settles credits
        │
        ▼
PostgreSQL · Redis · Object storage (report PDFs)
Monitoring: Sentry + structured logging (product backend only;
MiroFish logs stay internal and must not leak tracebacks to clients)
```

Deployment shape (to be confirmed in Phase 2, not assumed): product
backend and MiroFish run as **separate processes/containers** on the
server side, on a private network. MiroFish's `uploads/` directory is a
persistent volume owned by the MiroFish service alone. The product
backend never mounts it; it only reads via the MiroFish HTTP API, so a
MiroFish restart or host move cannot corrupt product data (events are
already copied into PostgreSQL).

AGPL handling: because MiroFish runs as a separate service, the
product backend is not merged into it. If a modified MiroFish is
deployed, its corresponding source must be offered to network users
per AGPL §13 — the deployment runbook must include that publication
step, and legal review must sign it off before public launch. Do not
ship a public build before that review.

## 3. Why FastAPI for the product backend (not MiroFish's Flask)

MiroFish's Flask app is a single-tenant demo console: in-process
runner state, disk-file persistence, no auth, Flask dev server. It
cannot serve as the product backend without a rewrite, and rewriting
it would deepen the AGPL entanglement. The product backend is therefore
a new FastAPI service implementing PRD §9 exactly, with MiroFish kept
pristine (or near-pristine) behind the adapter. This also keeps the
AGPL source-publication boundary clean: "the MiroFish service" is a
identifiable component with its own repository state.

## 4. Simulation engine interface (PRD §7.3, implemented as written)

```python
class SimulationEngine(Protocol):
    async def validate_config(self, config: SimulationConfig) -> list[str]: ...
    async def start(self, config: SimulationConfig) -> EngineRun: ...
    async def get_status(self, run_id: str) -> EngineStatus: ...
    async def get_events(self, run_id: str, cursor: str | None = None) -> EngineEventPage: ...
    async def get_results(self, run_id: str) -> EngineResults: ...
    async def cancel(self, run_id: str) -> None: ...
```

`SimulationConfig` is the product's normalized config (idea, audience,
mode). The adapter — not the app — translates it. No product code may
import anything from the MiroFish checkout.

## 5. MiroFishAdapter translation (the heart of the integration)

### 5.1 Idea + audience → MiroFish input

MiroFish accepts seed files + a natural-language requirement, not
structured JSON (audit §4). The adapter therefore builds, per run:

- **Seed brief** (`seed_brief.md`, generated deterministically from
  the idea version, never by silently inventing product facts):
  title, description, category, price (if given), intended customer,
  problem, and the audience definition as stated by the user. If a
  field is missing, the brief says so; the LLM is not asked to fill
  gaps as facts.
- **`simulation_requirement`** (natural language): "Simulate how the
  following audience segments discuss and react to this idea on
  social media: <audience>. Surface enthusiasm, objections (especially
  price), questions, and suggestions, and show how opinions shift as
  agents interact." Audience presets are rendered here as prose
  (e.g. "young professionals, 22–30, India, price-sensitive"), with a
  stored note that these are synthetic modelling choices.
- **Preset → engine knobs** (provisional, to be replaced by benchmark
  numbers): Quick = one platform, small `max_rounds` cap; Standard =
  parallel platforms, medium cap; Deep = parallel platforms, larger
  cap. Agent counts are **not** set here — they are read back from
  `prepare` (`profiles_count`) and stored as `actual_agent_count`.

### 5.2 MiroFish run → product simulation

Adapter sequence, mapped to audit §3:

```
validate_config → build seed brief + requirement
  → POST /api/graph/ontology/generate (multipart)
  → POST /api/graph/build, poll task until graph_id
  → POST /api/simulation/create
  → POST /api/simulation/prepare, poll prepare/status until ready
     (record actual_agent_count, entity_types)
  → POST /api/simulation/start (platform, max_rounds)
  → poll run-status + actions/posts/comments, normalising each
     action into a product event (below), persisting incrementally
  → on completion: POST /api/report/generate (supporting material)
  → POST /api/simulation/stop on cancel / timeout
```

Timeouts, retries, and partial-result preservation live in the worker:
a failed prepare/start leaves the product simulation `failed` with a
structured error code (PRD §9 format) and a refund decision; events
already persisted are kept and marked partial. Idempotency: the
product `POST /api/v1/simulations` key is stored, and a retried
request with the same key returns the original job instead of
starting a second MiroFish run (MiroFish itself has no idempotency).

### 5.3 Event normalisation (PRD §8.4)

MiroFish action → product event:

| MiroFish | Product event |
|---|---|
| `CREATE_POST` / `CREATE_COMMENT` (+ post/comment text) | `message` with agent name, platform, round, simulation-relative timestamp |
| `LIKE_POST` / `LIKE_COMMENT` | `reaction` (positive signal, count only) |
| `DISLIKE_POST` / `DISLIKE_COMMENT` | `reaction` (negative signal, count only) |
| `REPOST` / `QUOTE_POST` | `message` (share, with quoted content where available) |
| `FOLLOW` / `MUTE` / `DO_NOTHING` / searches / refresh | Not shown as conversation; counted in activity stats only |

Agent display identity comes from the OASIS profile (`agent_name`);
avatars are synthetic (generated initials/illustration, never a real
person's photo). `classification` (positive/negative/question/
suggestion/objection) is **not** copied from MiroFish — it is added
later by the analysis service and stored with `classified_by` and
`classification_version` so derived vs observed is always separable.

### 5.4 Status mapping

| Product (PRD §5 FR-04) | MiroFish / worker state |
|---|---|
| `draft` | Product-side only, not yet submitted |
| `queued` | Product job queued, adapter not yet called |
| `initializing` | ontology → graph build → create → prepare |
| `running` | MiroFish `running` |
| `analyzing` | MiroFish done; report + analysis running |
| `completed` / `failed` / `cancelled` | Terminal; maps from MiroFish `completed` / `failed` / `stopped` |

Live feed delivery: the worker polls MiroFish (no WS/SSE exists
there); the app receives events via the product backend's SSE stream
(`GET /api/v1/simulations/{id}/stream`) with polling fallback, per
PRD FR-05. Progress shown is real: current round, actions persisted,
and MiroFish status — never an invented percentage.

## 6. Data model (PRD §10, PostgreSQL, UUID keys)

Tables as specified in the PRD: `users, ideas, idea_versions,
audiences, simulations, simulation_events, simulation_results,
reports, credit_transactions, subscriptions, job_attempts`, plus an
`engine_runs` table (product simulation ↔ MiroFish `project_id` /
`simulation_id` / `graph_id`, engine name/version, seed brief hash,
requirement text) so any result can be traced to the exact engine
input. Foreign keys, ownership checks on every query (`user_id`),
indexes on `(simulation_id, event_sequence)` and `(user_id,
created_at)`. Migrations live under `infrastructure/migrations/`.

## 7. Analysis and reporting (Phase 4)

Pipeline (PRD §11.1): collect persisted events → dedupe/validate →
classify (rules + a small LLM classifier call through the product
backend's provider abstraction, with its own cost tracking) → extract
themes/objections/questions → segment by audience where the profile
data supports it → structured insights with event links → report.
Every metric records `numerator`, `denominator`, and `method`.
Reports always include engine, model (where disclosable), actual
agent count, rounds, audience assumptions, method, limitations, and
the §11.3 disclaimer verbatim. PDF export renders the same report;
share links are opt-in and private by default.

## 8. AI provider configuration (product backend)

A provider abstraction (`LLMProvider`) with model id, base URL,
timeouts, retries, and cost tracking. Supported at launch: any
OpenAI-compatible endpoint (the same class MiroFish needs). Bedrock
only via a verified OpenAI-compatible gateway — not assumed. Keys
live only in server environment / secret manager, never in the APK,
never in the repo, never in MiroFish's frontend bundle. The app ships
no secrets at all.

## 9. Security

- Supabase JWT validation on every product endpoint; MiroFish is
  reachable only from the worker's private network.
- Input sanitisation + upload validation (PRD §14) on idea images;
  user content and agent messages treated as untrusted text (no tool
  execution, no prompt-injection path into privileged instructions).
- Rate limiting per user; simulation jobs capped (max concurrent
  runs per user and globally — MiroFish's in-process runner is the
  bottleneck, so the queue, not the engine, enforces fairness).
- Audit logging for credit movements, report shares, and account
  deletion; backups for PostgreSQL; retention policy documented at
  launch (not invented here).

## 10. What is deliberately not in this architecture

- No direct app→MiroFish calls, no MiroFish Vue frontend reuse, no
  bundling of MiroFish code into the Flutter app, no shared database
  between product and engine, no credit logic in the app, no
  hardcoded demo feed in production code.
