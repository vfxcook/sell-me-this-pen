"""Background runner: executes one simulation job, persists real
events incrementally, and settles status honestly. A failed run keeps
whatever events were already persisted and is marked failed — never
backfilled, never silently marked successful.
"""
import uuid
from .db import SessionLocal, SimEvent, Simulation
from .engines.base import EngineError, SimulationConfig
from .engines import get_engine


async def run_simulation(sim_id: str):
    db = SessionLocal()
    try:
        sim = db.query(Simulation).filter_by(id=sim_id).first()
        if not sim:
            return
        from .db import Setting, Idea
        import json as _json
        row = db.query(Setting).filter_by(id=1).first()
        idea = db.query(Idea).filter_by(id=sim.idea_id).first()
        engine = get_engine(sim.engine_name, row)
        sim.status = "initializing"
        db.commit()
        config = SimulationConfig(
            idea_title=idea.title, idea_description=idea.description,
            category=idea.category, price_amount=idea.price_amount,
            price_currency=idea.price_currency,
            intended_customer=idea.intended_customer,
            problem=idea.problem, audience_preset=sim.audience_preset or "general",
            audience_json=_json.loads(sim.audience_json) if sim.audience_json else None,
            mode=sim.mode)
        sim.status = "running"
        db.commit()
        try:
            result = await engine.start(config)
        except EngineError as e:
            sim.status, sim.error_code, sim.error_message = \
                "failed", e.code, e.message
            db.commit()
            return
        except Exception as e:
            sim.status, sim.error_code, sim.error_message = \
                "failed", "ENGINE_ERROR", str(e)
            db.commit()
            return
        sim.actual_agent_count = result.actual_agent_count
        sim.engine_simulation_id = result.engine_simulation_id
        sim.engine_project_id = result.engine_project_id
        sim.engine_graph_id = result.engine_graph_id
        sim.is_demo = result.is_demo
        for i, ev in enumerate(result.events):
            db.add(SimEvent(id=f"evt_{uuid.uuid4().hex[:12]}",
                            simulation_id=sim.id,
                            agent_id=ev.agent_id, agent_name=ev.agent_name,
                            persona=ev.persona, event_type=ev.event_type,
                            content=ev.content,
                            classification=ev.classification,
                            simulation_timestamp=ev.simulation_timestamp,
                            event_sequence=i, is_demo=ev.is_demo))
        sim.status = "completed"
        db.commit()
    finally:
        db.close()
