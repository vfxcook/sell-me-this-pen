"""SimulationEngine interface (PRD 7.3). Product code depends only on
this module; engine adapters live beside it and are never imported
by the app. No adapter may invent events: an engine that cannot run
must raise EngineError, never return fabricated conversation.
"""
from dataclasses import dataclass, field


class EngineError(Exception):
    def __init__(self, code: str, message: str, retryable: bool = False,
                 status: int = 503):
        super().__init__(message)
        self.code, self.message, self.retryable, self.status = \
            code, message, retryable, status


@dataclass
class SimulationConfig:
    idea_title: str
    idea_description: str
    category: str | None = None
    price_amount: int | None = None
    price_currency: str = "INR"
    intended_customer: str | None = None
    problem: str | None = None
    audience_preset: str = "general"
    audience_json: dict | None = None
    mode: str = "quick"  # quick | standard | deep
    max_rounds: int | None = None


@dataclass
class EngineEvent:
    agent_id: str
    agent_name: str
    persona: str
    content: str
    event_type: str = "message"
    classification: str | None = None
    simulation_timestamp: int = 0
    is_demo: bool = False


@dataclass
class EngineRunResult:
    actual_agent_count: int | None = None
    events: list[EngineEvent] = field(default_factory=list)
    engine_simulation_id: str | None = None
    engine_project_id: str | None = None
    engine_graph_id: str | None = None
    is_demo: bool = False


class SimulationEngine:
    name: str = "base"

    async def validate_config(self, config: SimulationConfig):
        if not config.idea_title or not config.idea_description:
            raise EngineError("INVALID_INPUT",
                              "Idea title and description are required.",
                              retryable=False, status=400)

    async def start(self, config: SimulationConfig) -> EngineRunResult:
        raise NotImplementedError

    async def cancel(self, run_id: str):
        return None
