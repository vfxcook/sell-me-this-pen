"""Database: SQLAlchemy models. DATABASE_URL env switches to Postgres
in production; default is a local SQLite file for development.
Schema mirrors PRD section 10, plus engine_runs trace fields on
Simulation (mirofish project/simulation/graph ids) and is_demo.
Auth is a stub in this phase (see README): a single dev user id from
the X-User-Id header, default 'local-user'. Supabase JWT validation
is Phase 2 work and must land before any multi-user deployment.
"""
import os
from sqlalchemy import (Boolean, Column, DateTime, ForeignKey, Integer,
                        String, Text, create_engine)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker
from datetime import datetime, timezone

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./sellme.db")
_engine_kwargs = {"connect_args": {"check_same_thread": False}} \
    if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, **_engine_kwargs)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()


def utcnow():
    return datetime.now(timezone.utc)


class Setting(Base):
    __tablename__ = "settings"
    id = Column(Integer, primary_key=True)  # always 1: single server config
    engine = Column(String, default="demo")  # mirofish | direct | demo
    llm_api_key_enc = Column(Text, nullable=True)
    llm_base_url = Column(String, nullable=True)
    llm_model_name = Column(String, nullable=True)
    zep_api_key_enc = Column(Text, nullable=True)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)


class Idea(Base):
    __tablename__ = "ideas"
    id = Column(String, primary_key=True)
    user_id = Column(String, index=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=False)
    category = Column(String, nullable=True)
    price_amount = Column(Integer, nullable=True)
    price_currency = Column(String, default="INR")
    intended_customer = Column(String, nullable=True)
    problem = Column(String, nullable=True)
    status = Column(String, default="active")
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    simulations = relationship("Simulation", back_populates="idea")


class Simulation(Base):
    __tablename__ = "simulations"
    id = Column(String, primary_key=True)
    user_id = Column(String, index=True)
    idea_id = Column(String, ForeignKey("ideas.id"))
    engine_name = Column(String, nullable=False)
    engine_version = Column(String, nullable=True)
    status = Column(String, default="queued")
    mode = Column(String, default="quick")
    audience_preset = Column(String, nullable=True)
    audience_json = Column(Text, nullable=True)
    is_demo = Column(Boolean, default=False)
    actual_agent_count = Column(Integer, nullable=True)
    engine_project_id = Column(String, nullable=True)
    engine_simulation_id = Column(String, nullable=True)
    engine_graph_id = Column(String, nullable=True)
    error_code = Column(String, nullable=True)
    error_message = Column(String, nullable=True)
    idempotency_key = Column(String, index=True, nullable=True)
    created_at = Column(DateTime, default=utcnow)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow)
    idea = relationship("Idea", back_populates="simulations")
    events = relationship("SimEvent", back_populates="simulation",
                          order_by="SimEvent.event_sequence")


class SimEvent(Base):
    __tablename__ = "simulation_events"
    id = Column(String, primary_key=True)
    simulation_id = Column(String, ForeignKey("simulations.id"), index=True)
    engine_event_id = Column(String, nullable=True)
    agent_id = Column(String, nullable=True)
    agent_name = Column(String, nullable=True)
    persona = Column(String, nullable=True)
    event_type = Column(String, default="message")
    content = Column(Text, nullable=False)
    classification = Column(String, nullable=True)
    simulation_timestamp = Column(Integer, nullable=True)
    event_sequence = Column(Integer, nullable=False)
    is_demo = Column(Boolean, default=False)
    created_at = Column(DateTime, default=utcnow)
    simulation = relationship("Simulation", back_populates="events")


def init_db():
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
