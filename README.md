# Sell Me This Pen

AI-powered idea validation and audience simulation platform.
Tagline: Pitch it. Test it. Improve it.

## Status — 2026-10-28: implementation underway (user decision)

Frame (2026-10-28 ~00:17 IST) overrode the Phase 0 gate: keys and
remaining blockers can be set later; build now, with a 3-option engine
switch in Settings and key fields in Settings. Phase 0 PoC itself is
still NOT passed — production simulations will honestly report
ENGINE_NOT_CONFIGURED until keys are set. No fake production data.

## Status — 2026-10-28 (earlier): Phase 0, NOT PASSED

- `MIROFISH_AUDIT.md` — verified MiroFish findings (licence, interfaces,
  dependencies, model requirements, programmatic invocation).
- `ARCHITECTURE.md` — adapter-based design; the Flutter app never talks
  to MiroFish directly.
- `IMPLEMENTATION_PLAN.md` — phased plan, gated on the PoC.
- `poc/` — reproducible PoC attempt. **Result: BLOCKED, no genuine
  simulation run, no Flutter screens built** (per the PRD gate).

Blockers, in the order they must be cleared:
1. Python 3.11 or Docker (full install fails on this VM's Python 3.12:
   `camel-oasis==0.2.5` requires Python <3.12).
2. An OpenAI-compatible LLM API key + a Zep Cloud API key (both
   mandatory; `Config.validate()` fails without them).
3. AGPL-3.0 legal review before any public SaaS launch.
4. Benchmarks (agent counts, rounds, tokens, cost) before presets or
   credit prices can be set.
5. No mobile mockup file arrived in the commissioning chat — PRD §6.1
   colour/type tokens are the fallback design reference.

No simulated conversation in this repository is engine output. The
workspace method skill (`custom-skills/mirofish-simulation`) is a
prompting method distilled from MiroFish, not the engine, and must
never be presented as engine output.

## Layout (PRD §19, built as phases land)

```
sell-me-this-pen/
  MIROFISH_AUDIT.md  ARCHITECTURE.md  IMPLEMENTATION_PLAN.md  README.md
  poc/  (run_poc.py, poc_log.txt, full_install.log)
  apps/mobile/        (Phase 1 — gated)
  services/api/       (Phase 2)
  services/worker/    (Phase 2–3, incl. engines/mirofish.py)
  packages/api-contracts/
  infrastructure/     (docker, migrations, deployment)
  docs/               (PRD.md, API.md, DEPLOYMENT.md, TESTING.md)
```
