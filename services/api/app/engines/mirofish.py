"""MiroFishAdapter — talks to a running MiroFish Flask service over
HTTP (default http://127.0.0.1:5001, env MIROFISH_BASE_URL). Verified
against the clone's real routes (see MIROFISH_AUDIT.md section 3):

  POST /api/graph/ontology/generate (multipart files + requirement)
  POST /api/graph/build -> poll /api/graph/task/<id>
  POST /api/simulation/create
  POST /api/simulation/prepare -> poll /api/simulation/prepare/status
  POST /api/simulation/start  (platform, max_rounds)
  GET  /api/simulation/<id>/actions, /posts, /run-status
  POST /api/simulation/stop

Translation (audit section 5): the product idea + audience are
rendered into a deterministic seed brief (no invented product facts)
plus a natural-language simulation_requirement. Agent count is read
back from prepare (profiles_count), never requested. If keys or the
service are missing, this raises ENGINE_NOT_CONFIGURED /
ENGINE_UNAVAILABLE — it never synthesises a conversation.
NOTE: this adapter has not yet run end-to-end against a live MiroFish
service (keys + Python 3.11/Docker still pending); its not-configured
path and seed-brief builder are unit-tested, the live path is marked
as such in tests.
"""
import httpx, json, os
from .base import (EngineError, EngineEvent, EngineRunResult,
                   SimulationConfig, SimulationEngine)

BASE = os.environ.get("MIROFISH_BASE_URL", "http://127.0.0.1:5001")
MODE_ROUNDS = {"quick": 5, "standard": 10, "deep": 20}
PLATFORM_ACTIONS = {"CREATE_POST", "CREATE_COMMENT", "REPOST", "QUOTE_POST"}


def build_seed_brief(config: SimulationConfig) -> str:
    lines = [f"# Idea: {config.idea_title}", "", config.idea_description, ""]
    if config.category:
        lines.append(f"Category: {config.category}")
    if config.price_amount is not None:
        lines.append(f"Proposed price: {config.price_amount} "
                     f"{config.price_currency}")
    else:
        lines.append("Proposed price: not provided by the user.")
    if config.intended_customer:
        lines.append(f"Intended customer: {config.intended_customer}")
    if config.problem:
        lines.append(f"Problem being solved: {config.problem}")
    lines.append(f"Audience preset selected by the user: "
                 f"{config.audience_preset}")
    if config.audience_json:
        lines.append("Audience details (as entered by the user): "
                     f"{json.dumps(config.audience_json)}")
    return "\n".join(lines)


def build_requirement(config: SimulationConfig) -> str:
    return (
        f"Simulate how the audience '{config.audience_preset}' discusses "
        f"and reacts to the idea in the seed brief on social media. "
        f"Surface enthusiasm, objections (especially about price, if a "
        f"price is given), questions, and suggestions, and show how "
        f"opinions shift as agents interact with each other.")


class MiroFishEngine(SimulationEngine):
    name = "mirofish"

    def __init__(self, llm_key: str | None, zep_key: str | None,
                 base: str = BASE):
        self.llm_key, self.zep_key, self.base = llm_key, zep_key, base

    async def validate_config(self, config: SimulationConfig):
        await super().validate_config(config)
        if not self.llm_key or not self.zep_key:
            raise EngineError(
                "ENGINE_NOT_CONFIGURED",
                "MiroFish needs an LLM key and a Zep key. Set them in "
                "Settings, then run again.", retryable=False, status=503)

    async def start(self, config: SimulationConfig) -> EngineRunResult:
        await self.validate_config(config)
        brief, req = build_seed_brief(config), build_requirement(config)
        try:
            async with httpx.AsyncClient(timeout=120) as c:
                health = await c.get(f"{self.base}/health")
                if health.status_code != 200:
                    raise EngineError("ENGINE_UNAVAILABLE",
                                      "MiroFish service did not answer "
                                      "its health check.", retryable=True)
                # 1. ontology (multipart: seed brief as a file)
                r = await c.post(
                    f"{self.base}/api/graph/ontology/generate",
                    data={"simulation_requirement": req,
                          "project_name": config.idea_title},
                    files={"files": ("seed_brief.md",
                                     brief.encode(), "text/markdown")})
                data = r.json()
                if not data.get("success"):
                    raise EngineError("ENGINE_ERROR",
                                      f"Ontology generation failed: "
                                      f"{data.get('error')}", retryable=True)
                project_id = data["data"]["project_id"]
                # 2. graph build
                r = await c.post(f"{self.base}/api/graph/build",
                                 json={"project_id": project_id})
                task_id = r.json().get("data", {}).get("task_id")
                graph_id = None
                if task_id:
                    for _ in range(60):
                        t = await c.get(
                            f"{self.base}/api/graph/task/{task_id}")
                        td = t.json().get("data", {})
                        graph_id = td.get("graph_id")
                        if graph_id or td.get("status") == "failed":
                            break
                        import asyncio; await asyncio.sleep(10)
                # 3-4. create + prepare
                r = await c.post(f"{self.base}/api/simulation/create",
                                 json={"project_id": project_id,
                                       "graph_id": graph_id})
                sim_id = r.json()["data"]["simulation_id"]
                await c.post(f"{self.base}/api/simulation/prepare",
                             json={"simulation_id": sim_id})
                profiles_count = None
                for _ in range(120):
                    p = await c.post(
                        f"{self.base}/api/simulation/prepare/status",
                        json={"simulation_id": sim_id})
                    pd = p.json().get("data", {})
                    if pd.get("status") in ("ready", "completed"):
                        profiles_count = pd.get("profiles_count")
                        break
                    if pd.get("status") == "failed":
                        raise EngineError("ENGINE_ERROR",
                                          "Simulation prepare failed.",
                                          retryable=True)
                    import asyncio; await asyncio.sleep(10)
                # 5. start + poll actions
                await c.post(f"{self.base}/api/simulation/start",
                             json={"simulation_id": sim_id,
                                   "platform": "parallel",
                                   "max_rounds": config.max_rounds or
                                   MODE_ROUNDS.get(config.mode, 10)})
                events: list[EngineEvent] = []
                for _ in range(120):
                    s = await c.get(
                        f"{self.base}/api/simulation/{sim_id}/run-status")
                    st = s.json().get("data", {})
                    a = await c.get(
                        f"{self.base}/api/simulation/{sim_id}/actions",
                        params={"limit": 200})
                    for act in a.json().get("data", {}).get("actions", []):
                        if act.get("action_type") not in PLATFORM_ACTIONS:
                            continue
                        args = act.get("action_args", {}) or {}
                        text = args.get("content") or args.get("post_content") \
                            or act.get("result") or ""
                        if text:
                            events.append(EngineEvent(
                                agent_id=str(act.get("agent_id")),
                                agent_name=act.get("agent_name", "Agent"),
                                persona=act.get("platform", ""),
                                content=text,
                                simulation_timestamp=act.get("round_num", 0)))
                    if st.get("runner_status") in ("completed", "stopped",
                                                   "failed"):
                        break
                    import asyncio; await asyncio.sleep(10)
                return EngineRunResult(
                    actual_agent_count=profiles_count, events=events,
                    engine_simulation_id=sim_id,
                    engine_project_id=project_id, engine_graph_id=graph_id)
        except EngineError:
            raise
        except Exception as e:
            raise EngineError("ENGINE_UNAVAILABLE",
                              f"Could not reach the MiroFish service: {e}",
                              retryable=True)

    async def cancel(self, run_id: str):
        try:
            async with httpx.AsyncClient(timeout=30) as c:
                await c.post(f"{self.base}/api/simulation/stop",
                             json={"simulation_id": run_id})
        except Exception:
            pass
