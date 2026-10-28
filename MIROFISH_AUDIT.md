# MiroFish Audit — Sell Me This Pen, Phase 0 (Technical Discovery)

Date: 2026-10-28. Auditor: lead engineer (this session).
Source inspected: local clone at `~/workspace/mirofish/` (origin
`https://github.com/666ghj/MiroFish.git`, HEAD `7657031`, 2026-10-02),
plus the workspace method skill at
`~/workspace/custom-skills/mirofish-simulation/SKILL.md`.
Every claim below is either quoted from a file in that clone or from a
command actually run in this session. Anything not run is marked NOT RUN.
No MiroFish endpoint, function, or configuration field has been invented.

## Verdict up front

MiroFish is a **real, runnable-in-principle engine**, but it is **not a
library, not a skill, and not a drop-in simulation API** for the PRD's
normalized idea/audience JSON. It is a single-tenant Flask web app that
turns seed documents + a natural-language question into a Twitter/Reddit
social simulation via OASIS, backed by an LLM and Zep Cloud.

**Phase 0 exit criterion is NOT met.** A genuine MiroFish simulation was
not run in this session. The PoC stopped at two hard gates, both
reproduced empirically (see §10):

1. Dependencies are not installed on this VM (the October venv is an
   empty skeleton; `flask`, `openai`, `zep_cloud`, `camel-oasis` are all
   missing).
2. Both required credentials are absent: `Config.validate()` returns
   exactly `['LLM_API_KEY 未配置', 'ZEP_API_KEY 未配置']`, and `run.py`
   exits on that check. No `.env` exists in the clone.

Per the PRD's own gate ("Do not begin building all the Flutter screens
until the simulation proof of concept succeeds"), **no Flutter screens
have been built in this delivery.** Building them now would produce the
static prototype the PRD forbids.

## 1. License and commercial use — READ THIS FIRST

- License file: `LICENSE` is the **GNU Affero General Public License
  v3 (AGPL-3.0)**, confirmed in three places: the `LICENSE` text itself,
  root `package.json` (`"license": "AGPL-3.0"`), and
  `backend/pyproject.toml` (`license = { text = "AGPL-3.0" }`).
- What that means, in plain terms: AGPL is copyleft, and unlike plain
  GPL it is triggered by **network use**. If Sell Me This Pen runs a
  modified MiroFish on a server and lets users reach it over the
  network, AGPL §13 requires offering those users the corresponding
  source of the MiroFish version actually running.
- Consequence for the PRD's Definition of Done item "Commercial license
  compatibility has been verified": **it has NOT been verified as
  compatible with a closed-source SaaS.** The compatible routes are:
  (a) comply — deploy MiroFish unmodified-or-modified but publish its
  corresponding source and keep the product backend as a separate
  process that talks to it over HTTP (do not merge the codebases);
  (b) obtain a separate commercial licence from the MiroFish team, if
  they offer one (not investigated — no licence-offer text was found in
  the repo); or (c) replace the engine. This needs a legal review
  before any public launch. This document is not legal advice.
- Dependency licences (OASIS/CAMEL, Zep Cloud SDK, etc.) were **not**
  audited in this pass — flagged as a Phase 0 remainder, not assumed.

## 2. What MiroFish actually is

- README tagline: "A Simple and Universal Swarm Intelligence Engine,
  Predicting Anything." Workflow (README §Workflow): Graph Building
  (seed extraction, memory injection, GraphRAG) → Environment Setup
  (entity extraction, persona generation, agent configuration) →
  Simulation (dual-platform parallel simulation, temporal memory
  updates) → Report Generation (ReportAgent) → Deep Interaction (chat
  with any agent, chat with ReportAgent).
- Engine core: **OASIS (Open Agent Social Interaction Simulations)** by
  CAMEL-AI — acknowledged in the README. The simulation is a simulated
  **Twitter + Reddit**, not a generic "audience room": agents post,
  like, repost, comment, follow, and mute.
- Frontend: Vue 3 + Vite + vue-router + d3 (`frontend/package.json`).
  It is a demo console for the engine, not something Sell Me This Pen
  should reuse or ship.
- There is **no skill file in the repository**: no `SKILL.md`, no
  Muse/agent skill, no `.claude` definition was found. The skill at
  `~/workspace/custom-skills/mirofish-simulation/SKILL.md` is a
  **distilled 5-step method** (ontology-first, deep personas, T0→T1→T2,
  God's-eye injections, ReportAgent synthesis) written from reading
  MiroFish in October 2026 — it is a prompting method, not the engine,
  and its output must never be presented as engine output.

## 3. Supported interfaces (verified in code)

Backend: Flask app factory `create_app()` in `backend/app/__init__.py`,
blueprints mounted at:

| Blueprint | Prefix | Purpose |
|---|---|---|
| `graph_bp` | `/api/graph` | Projects, ontology, graph build |
| `simulation_bp` | `/api/simulation` | Create, prepare, start, stop, read |
| `report_bp` | `/api/report` | ReportAgent reports |
| health | `/health` | `{"status": "ok", "service": "MiroFish Backend"}` |

Default ports: backend `5001`, frontend `3000` (README Quick Start,
`docker-compose.yml`). Entry point: `backend/run.py` (Flask dev server,
`threaded=True` — not a production server).

### The real end-to-end call sequence

1. `POST /api/graph/ontology/generate` — multipart/form-data, **files
   (PDF/MD/TXT) are mandatory**, plus `simulation_requirement`
   (mandatory, natural language) and optional `project_name`,
   `additional_context`. Returns `project_id` + an ontology of
   **exactly 10 entity types** (enforced in
   `services/ontology_generator.py`, last two being fallback types
   including `Person`) + `analysis_summary`.
2. `POST /api/graph/build` — async background task; builds the Zep
   Cloud graph from the extracted text. Poll `GET /api/graph/task/<id>`.
   Result: a Zep `graph_id` stored on the project.
3. `POST /api/simulation/create` — JSON `{project_id, graph_id?,
   enable_twitter=true, enable_reddit=true}` → `simulation_id`,
   status `created`.
4. `POST /api/simulation/prepare` — async; LLM-generates OASIS agent
   profiles from Zep entities (`use_llm_for_profiles`, default true)
   and the `simulation_config.json`. Poll
   `POST /api/simulation/prepare/status`. Ready means `state.json`
   status `ready` + `config_generated=true` + files
   `reddit_profiles.json`, `twitter_profiles.csv`,
   `simulation_config.json` present in
   `backend/uploads/simulations/<simulation_id>/`.
5. `POST /api/simulation/start` — JSON `{simulation_id,
   platform: "parallel"|"twitter"|"reddit" (default "parallel"),
   max_rounds? (optional cap), enable_graph_memory_update=false,
   force=false}`. Starts OASIS worker subprocesses.
6. Poll (all GET, **polling only**): `/<id>/run-status`,
   `/<id>/run-status/detail`, `/<id>/actions?limit&offset&platform&
   agent_id&round_num`, `/<id>/posts`, `/<id>/comments`,
   `/<id>/timeline`, `/<id>/agent-stats`, `/<id>/profiles`.
   The endpoints named `.../stream` in the report API return a full
   list in one response, not a stream — there is **no WebSocket and no
   SSE for live simulation events** in this backend.
7. `POST /api/simulation/stop`, then `POST /api/report/generate` →
   poll `POST /api/report/generate/status` → `GET /api/report/<id>`,
   `/sections`, `/download`. ReportAgent can also interview agents
   (`POST /api/simulation/interview`, `/batch`, `/all`; max 10 agents
   per interview tool call in `report_agent.py`).

There is **no Python library entry point** for Sell Me This Pen to
import: the services are Flask-coupled, keep state in process memory
(`SimulationRunner` process/thread dicts) and on local disk, and the
OASIS run itself is a `subprocess.Popen` of
`backend/scripts/run_parallel_simulation.py` /
`run_twitter_simulation.py` / `run_reddit_simulation.py`
(`--config <simulation_config.json> [--no-wait]`). Programmatic
invocation therefore means **HTTP calls to a running MiroFish service**,
or, for advanced use, invoking those scripts directly with a prepared
config — both still need the LLM + Zep environment.

### No auth, no multi-tenancy — do not expose it

- `CORS(app, resources={r"/api/*": {"origins": "*"}})` in
  `app/__init__.py`. No login, token, JWT, or per-user check exists
  anywhere in `backend/app` (grep for auth/token/jwt returns only
  unrelated `max_tokens` hits).
- Error responses in `simulation.py` include
  `traceback.format_exc()` on 500s. Default `SECRET_KEY =
  'mirofish-secret-key'` in `config.py`.
- MiroFish must therefore run as an **internal-only service** behind
  Sell Me This Pen's own authenticated backend, never directly
  reachable from the app or the internet.

## 4. Input contract mismatch with the PRD (the biggest design fact)

The PRD §8.3 normalized input is **not accepted by MiroFish**:

```json
{"idea": {"title": "...", "description": "...", "category": "...",
 "price": {"amount": 999, "currency": "INR"}},
 "audience": {"preset": "young_consumers", "country": "IN",
 "age_min": 18, "age_max": 30},
 "simulation": {"mode": "quick", "requested_agents": 50}}
```

MiroFish accepts none of those fields. Its real inputs are:

- Seed **files** (PDF/MD/TXT, 50 MB cap in `config.py`) — the PRD's
  idea description must be *rendered into a seed document* by the
  adapter, not sent as JSON.
- A natural-language `simulation_requirement` — the adapter must
  compose this from idea + audience + question (e.g. "Simulate how
  these audience segments react to this product, its price, and its
  pitch; surface objections, questions, and suggestions").
- Audience presets (General Consumers, Students, Parents, …) have no
  counterpart parameter. They can only influence the simulation via
  the seed text, the requirement text, and — indirectly — the entities
  the LLM extracts into the Zep graph. Any audience attribute MiroFish
  cannot represent must be handled exactly as PRD FR-03 says: transform
  it in a documented way or disable that option. It cannot be passed
  through silently.
- **Agent count is not a request parameter.** It is derived: profiles
  are generated from Zep graph entities, and the config generator
  bounds hourly active agents by `max(1, int(num_entities * 0.9))`
  (`simulation_config_generator.py`). `requested_agents: 50` therefore
  cannot be honoured literally; the adapter must report
  `actual_agent_count = profiles_count` after prepare, and the
  Quick/Standard/Deep presets must be defined by **measured** knobs
  only: platform choice, `max_rounds` cap, and seed/requirement scope.
  Until benchmarking runs, no agent count may be promised in the app.
- Likewise there is no price, category, or country parameter: price
  objections can only emerge if price is written into the seed brief
  and the requirement asks about it.

## 5. Output contract — what the engine really returns

- Agent actions (`AgentAction` in `simulation_runner.py`): `round_num`,
  `timestamp`, `platform` (twitter/reddit), `agent_id`, `agent_name`,
  `action_type`, `action_args`, `result`, `success`. Action types are
  fixed sets in `config.py`: Twitter — `CREATE_POST, LIKE_POST,
  REPOST, FOLLOW, DO_NOTHING, QUOTE_POST`; Reddit — `LIKE_POST,
  DISLIKE_POST, CREATE_POST, CREATE_COMMENT, LIKE_COMMENT,
  DISLIKE_COMMENT, SEARCH_POSTS, SEARCH_USER, TREND, REFRESH,
  DO_NOTHING, FOLLOW, MUTE`.
- Posts/comments are read from per-simulation SQLite files
  (`<platform>_simulation.db`, `post` table) and from `actions.jsonl`.
- **No built-in classification exists** for positive / negative /
  neutral / question / suggestion / objection. The PRD's
  classification layer, theme extraction, and interest metrics must be
  built in Sell Me This Pen's analysis service and labelled as
  *derived classifications*, with denominators shown — never as engine
  output and never as purchase intent.
- Simulation states (MiroFish's own, `simulation_manager.py`):
  `created, preparing, ready, running, stopping, paused, stopped,
  completed, failed`. The PRD's `draft, queued, initializing,
  analyzing, cancelled` states must be mapped in the adapter (queued/
  draft live in our backend; `analyzing` = report generation).
- ReportAgent output is a Markdown report with sections, built by
  interviewing agents and querying Zep tools — useful as *supporting
  material*, not as a substitute for the PRD's structured analytics.

## 6. Dependencies and runtime requirements

- Python `>=3.11, <3.13` (`pyproject.toml`); Node `>=18`; `uv`
  (README). **Effective Python is 3.11 only, verified by install
  failure:** `pip install -r backend/requirements.txt` on this VM's
  Python 3.12.3 fails with `No matching distribution found for
  camel-oasis==0.2.5`, because every published camel-oasis version
  requires Python `<3.12, >=3.10`. The project's own `Dockerfile`
  confirms it: `FROM python:3.11`. This VM has only Python 3.12.3
  and Node v24.22.1, and **no `uv`, no `docker`, no `flutter`, no
  `dart`** on PATH (checked 2026-10-28) — a Python 3.11 install (or
  the Docker image route) is itself Phase 0 work.
- Backend deps (`requirements.txt` / `pyproject.toml`): Flask ≥3,
  flask-cors, `openai` SDK, `zep-cloud==3.25.0`, `httpx`,
  `camel-oasis==0.2.5`, `camel-ai==0.2.78`, PyMuPDF, charset-normalizer,
  chardet, python-dotenv, pydantic ≥2. Docker image:
  `ghcr.io/666ghj/mirofish:latest` (`docker-compose.yml`, ports
  3000/5001, volume `./backend/uploads`).
- Persistence is **local disk only**: `backend/uploads/projects/`
  (project JSON + extracted text) and
  `backend/uploads/simulations/<id>/` (`state.json`,
  `simulation_config.json`, profiles, `actions.jsonl`, SQLite DBs,
  logs). No database, no queue, no idempotency, no job retry, no
  credit system. All of that must live in Sell Me This Pen's backend;
  MiroFish state does not survive a move to another host unless the
  uploads directory moves with it, and its in-process runner state does
  not survive a restart.
- Resource note: this VM has 2 CPUs and 7.7 GB RAM with only ~350 MB
  free at audit time. OASIS runtime cost is dominated by LLM API calls,
  not local GPU, but a full dependency install (CAMEL pulls a large
  ML-adjacent tree) is heavy — see §10.

## 7. AI model requirements

- Mandatory env (`backend/app/config.py`, `Config.validate()`):
  `LLM_API_KEY`, `ZEP_API_KEY`. If either is missing, `run.py`
  prints the error(s) and exits(1) — after imports succeed.
- LLM via **OpenAI-compatible Chat Completions only**
  (`utils/llm_client.py` uses `openai.OpenAI(base_url=...)`, with a
  JSON-response-format compatibility shim). README recommends
  Alibaba Qwen-plus via Bailian
  (`https://dashscope.aliyuncs.com/compatible-mode/v1`) and warns:
  "High consumption, try simulations with fewer than 40 rounds
  first." Config defaults (only if env vars are absent, key still
  required) are `https://api.openai.com/v1` / `gpt-4o-mini`.
- Optional second endpoint: `LLM_BOOST_API_KEY / _BASE_URL /
  _MODEL_NAME` — only if all three are present; otherwise the keys
  must not appear in `.env` at all.
- Zep is **Cloud-only**: `config.py` explicitly rejects `ZEP_API_URL`
  ("MiroFish 仅连接 Zep Cloud"). There is no self-hosted Zep path, no
  local-memory fallback, and no offline mode. A free Zep Cloud quota
  is claimed by the README to suffice for simple usage (unverified).
- **AWS Bedrock is not directly supported.** Nothing in the backend
  speaks Bedrock's API. Bedrock could only be used behind an
  OpenAI-compatible gateway (e.g. a LiteLLM-style proxy) — that
  gateway is unverified, unbuilt, and must not be claimed as supported
  until tested. The same applies to Anthropic direct: only via an
  OpenAI-compatible endpoint.
- Token/cost numbers: **NOT RUN.** No benchmark, token count, or
  per-simulation cost exists yet. The only numbers in the code are
  defaults: `OASIS_DEFAULT_MAX_ROUNDS=10`, report interview cap 10
  agents, `REPORT_AGENT_MAX_TOOL_CALLS=5`,
  `REPORT_AGENT_MAX_REFLECTION_ROUNDS=2`, temperature 0.5. Pricing
  and credit allowances cannot be set from these.

## 8. Capability matrix

| PRD need | MiroFish verdict |
|---|---|
| Multi-agent discussion of an idea | Supported in principle — via seed doc + requirement → social sim |
| Programmatic start / poll / stop | Yes — HTTP API (§3); polling, not streaming |
| Deterministic agent count (e.g. 50) | **No** — LLM-derived from graph entities |
| Structured idea/audience JSON input | **No** — must be translated to seed + requirement text |
| Price / category / country as fields | **No** — only via seed text |
| Reaction classification, themes, objections | **No** — analysis layer must be built |
| Quick / Standard / Deep presets | **No native presets** — only platform + max_rounds knobs |
| Realtime feed (WS/SSE) | **No** — poll actions/posts/comments |
| Auth / per-user isolation / credits | **No** — must be built in our backend |
| Cancel | Yes — `/stop` (with safe-finalization 409s) |
| Retry / idempotency | **No** — must be built in our backend |
| Offline / keyless run | **No** — LLM + Zep Cloud keys mandatory |
| Commercial closed-SaaS licence | **Not verified** — AGPL, see §1 |

## 9. Unsupported / risky features (do not promise)

- Predicting sales, purchase intent, or market share — the PRD itself
  forbids presenting synthetic results this way; the engine only
  simulates social posts.
- Millions of agents, video-call agents, autonomous purchasing —
  outside OASIS's Twitter/Reddit action sets.
- "Live" progress percentages — MiroFish exposes rounds and action
  counts; the app must show those real values (or a neutral
  processing state), never an invented percentage.
- Running MiroFish inside the Flutter app or on the phone — it is a
  server workload with subprocess workers and cloud dependencies.
- Reusing MiroFish's Vue frontend as the product UI.

## 10. PoC attempt log (this session, reproducible)

Working directory for the PoC: `~/workspace/sell-me-this-pen/poc/`
(rerunnable script `run_poc.py`, full log `poc_log.txt`).

1. Environment check: Python 3.12.3 ✓, Node v24.22.1 ✓, `uv` ✗,
   `docker` ✗, `flutter`/`dart` ✗, Java (system) ✗ — but a JDK 17
   exists under `~/workspace/jdk17/` from earlier Godot work.
   Clone state: no `.env`, no `backend/uploads/`, venv skeleton only
   (76 KB, no packages) — the October `setup:backend` never completed.
2. Minimal install (`flask flask-cors python-dotenv pydantic`) then
   `python backend/run.py` → `ModuleNotFoundError: No module named
   'openai'` (import chain: `app/__init__` → `utils/__init__` →
   `llm_client` → `openai`).
3. After adding `openai httpx`, importing `Config` alone and calling
   `Config.validate()` → `['LLM_API_KEY 未配置', 'ZEP_API_KEY 未配置']`.
   This is the exact gate `run.py` enforces before serving.
4. `create_app()` attempt → next missing module: `zep_cloud`
   (chain: `services/__init__` → `graph_builder` → `zep_cloud`).
   Note: `create_app()` itself does not call `validate()`; a booted
   app would answer `/health` but fail at the first LLM/Zep call.
5. Full `pip install -r backend/requirements.txt` was run during
   this audit and **failed** (log: `poc/full_install.log`):
   `ERROR: No matching distribution found for camel-oasis==0.2.5`
   on Python 3.12 — see §6. The install gate is therefore a third,
   independent blocker (B4a in the table below): Python 3.11 or the
   Docker image is required before the key gate can even be reached
   in a full boot.
   **Even a fully successful install does not complete the PoC** —
   the key gate remains. A genuine simulation additionally needs a
   valid LLM key, a valid Zep Cloud key, seed material, and a
   completed prepare + start + poll cycle, none of which has happened.

## 11. Blockers and decisions required

| # | Blocker | Unblocks | Owner |
|---|---|---|---|
| B1 | No LLM API key (OpenAI-compatible) | Any real simulation | Frame — via secure entry, never in chat |
| B2 | No Zep Cloud API key | Graph build + prepare (both hard-require Zep) | Frame — via secure entry |
| B3 | AGPL-3.0 vs closed SaaS | Public launch; affects deployment + source-publication plan | Legal review before launch |
| B4 | No benchmark (agents, rounds, tokens, cost, latency) | Preset definitions, credit pricing, PRD §2.2 targets | Benchmark run, once B1+B2 clear |
| B4a | Full install fails on Python 3.12 (camel-oasis caps at <3.12) | Booting the real engine on this VM | Python 3.11 install, or Docker image `ghcr.io/666ghj/mirofish:latest` (needs Docker, also absent) |
| B5 | No Flutter/Docker/uv toolchain on this VM | Android APK build + containerised backend | Toolchain install (Phase 1/6) |
| B6 | No mobile mockup file arrived in this chat | Pixel-matching Phase 1 screens | Frame — send the mockup, or confirm PRD §6.1 tokens suffice |

## 12. Recommendation

Do not build Flutter screens yet (PRD gate). Do not substitute the
distilled method skill's output for engine output, and do not hardcode
a demo conversation as "live". The next step is a single decision
from Frame: supply B1+B2 through the secure flow so the PoC can run
for real, or direct an engine change (e.g. a purpose-built multi-agent
adapter over a configurable provider, with MiroFish kept only as a
reference method). Either path keeps the architecture in
`ARCHITECTURE.md` intact, because the adapter boundary isolates the
engine.
