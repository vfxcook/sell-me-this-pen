import uuid
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from ..db import Idea, get_db

router = APIRouter(prefix="/api/v1/ideas", tags=["ideas"])


def user_id(x_user_id: str | None = Header(default=None)):
    return x_user_id or "local-user"


class IdeaIn(BaseModel):
    title: str
    description: str
    category: str | None = None
    price_amount: int | None = None
    price_currency: str = "INR"
    intended_customer: str | None = None
    problem: str | None = None


def _out(i: Idea):
    return {"id": i.id, "title": i.title, "description": i.description,
            "category": i.category, "price_amount": i.price_amount,
            "price_currency": i.price_currency,
            "intended_customer": i.intended_customer,
            "problem": i.problem, "status": i.status,
            "created_at": i.created_at.isoformat() if i.created_at else None}


@router.post("", status_code=201)
def create_idea(body: IdeaIn, db: Session = Depends(get_db),
                uid: str = Depends(user_id)):
    if not body.title.strip() or not body.description.strip():
        raise HTTPException(400, "Title and description are required.")
    idea = Idea(id=f"idea_{uuid.uuid4().hex[:12]}", user_id=uid, **body.model_dump())
    db.add(idea)
    db.commit()
    return _out(idea)


@router.get("")
def list_ideas(db: Session = Depends(get_db), uid: str = Depends(user_id)):
    return [_out(i) for i in db.query(Idea).filter_by(user_id=uid)
            .order_by(Idea.created_at.desc()).all()]


@router.get("/{idea_id}")
def get_idea(idea_id: str, db: Session = Depends(get_db),
             uid: str = Depends(user_id)):
    idea = db.query(Idea).filter_by(id=idea_id, user_id=uid).first()
    if not idea:
        raise HTTPException(404, "Idea not found.")
    return _out(idea)
