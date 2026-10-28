from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from ..db import Setting, get_db
from ..settings_store import ENGINES, encrypt, engine_status

router = APIRouter(prefix="/api/v1/settings", tags=["settings"])


class SettingsUpdate(BaseModel):
    engine: str | None = None
    llm_api_key: str | None = None
    llm_base_url: str | None = None
    llm_model_name: str | None = None
    zep_api_key: str | None = None


def _row(db: Session) -> Setting:
    row = db.query(Setting).filter_by(id=1).first()
    if not row:
        row = Setting(id=1, engine="demo")
        db.add(row)
        db.commit()
        db.refresh(row)
    return row


@router.get("")
def get_settings(db: Session = Depends(get_db)):
    row = _row(db)
    st = engine_status(row.engine, row)
    return {"engine": row.engine, **st,
            "available_engines": [
                {"key": "mirofish",
                 "label": "MiroFish",
                 "description": "Full MiroFish engine (Twitter/Reddit social sim). Needs LLM key + Zep key."},
                {"key": "direct",
                 "label": "Direct multi-agent",
                 "description": "Lightweight multi-agent via LLM only, no Zep. Needs LLM key only."},
                {"key": "demo",
                 "label": "Demo (labelled sample)",
                 "description": "No keys. Sample data, clearly marked DEMO — never presented as real."}]}


@router.put("")
def update_settings(body: SettingsUpdate, db: Session = Depends(get_db)):
    row = _row(db)
    if body.engine is not None:
        if body.engine not in ENGINES:
            from fastapi import HTTPException
            raise HTTPException(400, f"Unknown engine: {body.engine}")
        row.engine = body.engine
    # Empty / omitted key fields mean 'leave unchanged' — never wipe.
    if body.llm_api_key:
        row.llm_api_key_enc = encrypt(body.llm_api_key)
    if body.llm_base_url is not None:
        row.llm_base_url = body.llm_base_url or None
    if body.llm_model_name is not None:
        row.llm_model_name = body.llm_model_name or None
    if body.zep_api_key:
        row.zep_api_key_enc = encrypt(body.zep_api_key)
    db.commit()
    return get_settings(db)
