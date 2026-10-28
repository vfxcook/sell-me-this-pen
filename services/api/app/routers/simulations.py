import json, uuid
from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from ..db import Idea, Setting, SimEvent, Simulation, get_db
from ..runner import run_simulation
from ..settings_store import engine_status

router = APIRouter(prefix="/api/v1/simulations", tags=["simulations"])


def user_id(x_user_id: str | None = Header(default=None)):
    return x_user_id or "local-user"


class SimIn(BaseModel):
    idea_id: str
    audience_preset: str = "general"
    audience: dict | None = None
    mode: str = "quick"


def _out(s: Simulation):
    return {"id": s.id, "idea_id": s.idea_id, "engine": s.engine_name,
            "status": s.status, "mode": s.mode,
            "audience_preset": s.audience_preset, "is_demo": s.is_demo,
            "actual_agent_count": s.actual_agent_count,
            "error": ({"code": s.error_code, "message": s.error_message,
                       "retryable": False} if s.error_code else None),
            "created_at": s.created_at.isoformat() if s.created_at else None}


def _settings(db: Session):
    row = db.query(Setting).filter_by(id=1).first()
    if not row:
        row = Setting(id=1, engine="demo")
        db.add(row)
        db.commit()
    return row


@router.post("/estimate")
def estimate(body: SimIn, db: Session = Depends(get_db)):
    """Honest estimate: cost and agent count are TBD until the
    MiroFish benchmark lands (audit B4). Never invent a number."""
    row = _settings(db)
    st = engine_status(row.engine, row)
    return {"engine": row.engine, "engine_ready": st["ready"],
            "missing_keys": st["missing_keys"],
            "estimated_credits": None,
            "estimated_credits_note": "TBD until benchmarked",
            "agent_count": None,
            "agent_count_note": "Determined by the engine at prepare time; "
                               "not promised in advance."}


@router.post("", status_code=201)
def create_sim(body: SimIn, bg: BackgroundTasks, db: Session = Depends(get_db),
               uid: str = Depends(user_id),
               idempotency_key: str | None = Header(default=None)):
    idea = db.query(Idea).filter_by(id=body.idea_id, user_id=uid).first()
    if not idea:
        raise HTTPException(404, "Idea not found.")
    if idempotency_key:
        existing = db.query(Simulation).filter_by(
            user_id=uid, idempotency_key=idempotency_key).first()
        if existing:
            return _out(existing)  # retried request: no second run, no double charge
    row = _settings(db)
    sim = Simulation(id=f"sim_{uuid.uuid4().hex[:12]}", user_id=uid,
                     idea_id=idea.id, engine_name=row.engine, status="queued",
                     mode=body.mode, audience_preset=body.audience_preset,
                     audience_json=json.dumps(body.audience or {}),
                     idempotency_key=idempotency_key)
    db.add(sim)
    db.commit()
    bg.add_task(run_simulation, sim.id)
    return _out(sim)


@router.get("")
def list_sims(db: Session = Depends(get_db), uid: str = Depends(user_id)):
    return [_out(s) for s in db.query(Simulation).filter_by(user_id=uid)
            .order_by(Simulation.created_at.desc()).all()]


@router.get("/{sim_id}")
def get_sim(sim_id: str, db: Session = Depends(get_db),
            uid: str = Depends(user_id)):
    sim = db.query(Simulation).filter_by(id=sim_id, user_id=uid).first()
    if not sim:
        raise HTTPException(404, "Simulation not found.")
    return _out(sim)


@router.get("/{sim_id}/events")
def get_events(sim_id: str, db: Session = Depends(get_db),
               uid: str = Depends(user_id)):
    sim = db.query(Simulation).filter_by(id=sim_id, user_id=uid).first()
    if not sim:
        raise HTTPException(404, "Simulation not found.")
    evs = db.query(SimEvent).filter_by(simulation_id=sim_id) \
        .order_by(SimEvent.event_sequence).all()
    return {"simulation_id": sim_id, "status": sim.status,
            "is_demo": sim.is_demo,
            "events": [{"id": e.id, "agent_id": e.agent_id,
                        "agent_name": e.agent_name, "persona": e.persona,
                        "event_type": e.event_type, "content": e.content,
                        "classification": e.classification,
                        "simulation_timestamp": e.simulation_timestamp,
                        "is_demo": e.is_demo} for e in evs]}


@router.get("/{sim_id}/results")
def get_results(sim_id: str, db: Session = Depends(get_db),
                uid: str = Depends(user_id)):
    sim = db.query(Simulation).filter_by(id=sim_id, user_id=uid).first()
    if not sim:
        raise HTTPException(404, "Simulation not found.")
    evs = db.query(SimEvent).filter_by(simulation_id=sim_id).all()
    total = len(evs)
    return {"simulation_id": sim_id, "status": sim.status,
            "is_demo": sim.is_demo, "engine": sim.engine_name,
            "actual_agent_count": sim.actual_agent_count,
            "disclaimer": "This report is generated from AI-simulated "
            "audience interactions. Results are exploratory and do not "
            "represent verified human consumer behavior, actual purchase "
            "intent, or statistically representative market research.",
            "metrics": [
                {"name": "messages_observed", "numerator": total,
                 "denominator": total,
                 "method": "Count of persisted message events."},
                {"name": "agents_observed",
                 "numerator": len({e.agent_id for e in evs}),
                 "denominator": sim.actual_agent_count,
                 "method": "Distinct agent ids among persisted events."}],
            "note": "No interest percentage is shown: no classification "
                    "or purchase-intent inference is made from synthetic "
                    "events in this phase."}


@router.post("/{sim_id}/cancel")
def cancel_sim(sim_id: str, db: Session = Depends(get_db),
               uid: str = Depends(user_id)):
    sim = db.query(Simulation).filter_by(id=sim_id, user_id=uid).first()
    if not sim:
        raise HTTPException(404, "Simulation not found.")
    if sim.status not in ("completed", "failed", "cancelled"):
        sim.status = "cancelled"
        db.commit()
    return _out(sim)
