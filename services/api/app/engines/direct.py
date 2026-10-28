"""DirectEngine — lightweight multi-agent simulation that needs only
an OpenAI-compatible LLM key (no Zep). Personas are deterministic
templates derived from the audience preset (configuration, not
results); every message is produced by a real LLM call at run time.
If no key is configured it raises ENGINE_NOT_CONFIGURED, never fake
dialogue. Classification is left unset here — the analysis layer
(Phase 4) owns it, so observed vs derived stay separable.
"""
import httpx
from .base import (EngineError, EngineEvent, EngineRunResult,
                   SimulationConfig, SimulationEngine)

PRESET_PERSONAS = {
    "general": ["Priya, 34, careful shopper", "Arjun, 28, early adopter",
                "Meera, 41, value-focused parent"],
    "students": ["Ananya, 20, film student on a tight budget",
                 "Rohan, 22, creator and side-hustler"],
    "young_professionals": ["Sara, 27, product manager",
                            "Kabir, 29, startup analyst"],
    "parents": ["Meera, 41, value-focused parent",
                "David, 38, busy father of two"],
    "fitness": ["Aisha, 30, gym regular", "Vikram, 33, marathon runner"],
    "technology": ["Kabir, 29, startup analyst",
                   "Neha, 26, software engineer"],
    "small_business": ["Ramesh, 45, shop owner",
                       "Sunita, 39, boutique founder"],
    "investors": ["David, 44, pre-seed investor",
                  "Anita, 39, angel investor"],
}
MODE_AGENTS = {"quick": 3, "standard": 6, "deep": 8}


class DirectEngine(SimulationEngine):
    name = "direct"

    def __init__(self, llm_key: str | None, base_url: str | None,
                 model: str | None):
        self.llm_key = llm_key
        self.base_url = (base_url or "https://api.openai.com/v1").rstrip("/")
        self.model = model or "gpt-4o-mini"

    async def validate_config(self, config: SimulationConfig):
        await super().validate_config(config)
        if not self.llm_key:
            raise EngineError(
                "ENGINE_NOT_CONFIGURED",
                "Direct engine needs an LLM key. Set it in Settings, "
                "then run again.", retryable=False, status=503)

    async def _chat(self, system: str, user: str) -> str:
        async with httpx.AsyncClient(timeout=120) as c:
            r = await c.post(
                f"{self.base_url}/chat/completions",
                headers={"Authorization": f"Bearer {self.llm_key}"},
                json={"model": self.model, "temperature": 0.8,
                      "messages": [{"role": "system", "content": system},
                                   {"role": "user", "content": user}]})
            r.raise_for_status()
            return r.json()["choices"][0]["message"]["content"].strip()

    async def start(self, config: SimulationConfig) -> EngineRunResult:
        await self.validate_config(config)
        pool = PRESET_PERSONAS.get(config.audience_preset,
                                   PRESET_PERSONAS["general"])
        count = min(MODE_AGENTS.get(config.mode, 3), len(pool))
        # Extend pool deterministically if a mode wants more agents.
        personas = [pool[i % len(pool)] for i in range(count)]
        price = (f" Proposed price: {config.price_amount} "
                 f"{config.price_currency}."
                 if config.price_amount is not None else "")
        brief = (f"Idea: {config.idea_title}. {config.idea_description}."
                 f"{price}")
        events: list[EngineEvent] = []
        posts: list[str] = []
        for i, persona in enumerate(personas):
            text = await self._chat(
                f"You are {persona}, a potential customer. React in "
                f"first person, 2-4 sentences, honestly: enthusiasm, "
                f"objections, or questions. Do not claim to be an AI.",
                f"React to this idea: {brief}")
            posts.append(text)
            events.append(EngineEvent(agent_id=f"agent_{i}",
                                      agent_name=persona.split(",")[0],
                                      persona=persona, content=text,
                                      simulation_timestamp=0))
        for i, persona in enumerate(personas):
            other = posts[(i + 1) % len(posts)]
            text = await self._chat(
                f"You are {persona}, a potential customer in a group "
                f"discussion. Reply in first person, 2-3 sentences: "
                f"agree, disagree, or ask a follow-up.",
                f"Another customer said: '{other}'\nIdea: {brief}\n"
                f"Reply to them.")
            events.append(EngineEvent(agent_id=f"agent_{i}",
                                      agent_name=persona.split(",")[0],
                                      persona=persona, content=text,
                                      event_type="message",
                                      simulation_timestamp=1))
        return EngineRunResult(actual_agent_count=len(personas),
                               events=events)
