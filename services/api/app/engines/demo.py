"""DemoEngine — LABELLED SAMPLE ONLY. Used only when the user has
explicitly selected engine='demo' in Settings (the default, so the
app is explorable before any keys are set). Every event carries
is_demo=True, the simulation row carries is_demo=True, and the API
response carries is_demo=True. The UI must show a DEMO banner.
This engine must never be used for a production simulation, and its
output must never be described as real audience feedback.
"""
from .base import (EngineEvent, EngineRunResult, SimulationConfig,
                   SimulationEngine)

SAMPLE = [
    ("Maya", "General consumer, 31",
     "I like the idea, but I would need to see it in action before "
     "paying for it."),
    ("Rohan", "Young professional, 27",
     "The pitch is clear. My main question is what it costs over a "
     "year, not just upfront."),
    ("Sara", "Student, 21",
     "Interesting, but it sounds expensive for someone on my budget. "
     "Is there a cheaper starting version?"),
]


class DemoEngine(SimulationEngine):
    name = "demo"

    async def start(self, config: SimulationConfig) -> EngineRunResult:
        await self.validate_config(config)
        events = [EngineEvent(agent_id=f"demo_{i}", agent_name=name,
                              persona=persona, content=text,
                              simulation_timestamp=i, is_demo=True)
                  for i, (name, persona, text) in enumerate(SAMPLE)]
        return EngineRunResult(actual_agent_count=len(SAMPLE),
                               events=events, is_demo=True)
