"""Backend tests. Run: .venv/bin/python -m pytest tests/ -q
Uses a throwaway SQLite file + settings key so tests never touch dev data.
"""
import os, sys, tempfile, time
os.environ["DATABASE_URL"] = "sqlite:///" + os.path.join(
    tempfile.mkdtemp(), "test.db")
os.environ["SETTINGS_KEY_FILE"] = os.path.join(tempfile.mkdtemp(), "k")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient  # noqa: E402
from app.main import app  # noqa: E402
from app.db import init_db  # noqa: E402
init_db()  # TestClient does not reliably fire on_event startup
from app.engines.mirofish import build_seed_brief, build_requirement  # noqa: E402
from app.engines.base import SimulationConfig  # noqa: E402

client = TestClient(app)


def test_health():
    assert client.get("/health").json()["status"] == "ok"


def test_settings_three_engines_and_masked_keys():
    r = client.get("/api/v1/settings").json()
    keys = [e["key"] for e in r["available_engines"]]
    assert keys == ["mirofish", "direct", "demo"]
    assert r["engine"] == "demo"  # default: explorable, labelled demo
    r = client.put("/api/v1/settings", json={
        "engine": "direct", "llm_api_key": "sk-test-12345678",
        "llm_base_url": "https://api.openai.com/v1",
        "llm_model_name": "gpt-4o-mini"}).json()
    assert r["engine"] == "direct"
    assert r["llm_api_key_masked"] == "••••5678"
    assert "sk-test" not in str(r)  # full key never returned
    # Empty key field on update must not wipe the stored key.
    r = client.put("/api/v1/settings", json={"engine": "direct"}).json()
    assert r["llm_api_key_masked"] == "••••5678"
    r = client.put("/api/v1/settings", json={"engine": "bogus"})
    assert r.status_code == 400


def test_idea_and_demo_simulation_is_flagged():
    idea = client.post("/api/v1/ideas", json={
        "title": "Smart Water Bottle",
        "description": "A bottle that tracks hydration."}).json()
    assert idea["id"]
    client.put("/api/v1/settings", json={"engine": "demo"})
    sim = client.post("/api/v1/simulations",
                      json={"idea_id": idea["id"], "mode": "quick"}).json()
    for _ in range(50):  # background task completes fast for demo
        got = client.get(f"/api/v1/simulations/{sim['id']}").json()
        if got["status"] == "completed":
            break
        time.sleep(0.1)
    assert got["status"] == "completed" and got["is_demo"] is True
    evs = client.get(f"/api/v1/simulations/{sim['id']}/events").json()
    assert evs["is_demo"] is True
    assert all(e["is_demo"] for e in evs["events"]) and len(evs["events"]) == 3
    res = client.get(f"/api/v1/simulations/{sim['id']}/results").json()
    assert "do not represent verified human" in res["disclaimer"]
    assert res["metrics"][0]["denominator"] == 3


def test_mirofish_without_keys_fails_honestly_not_fake():
    client.put("/api/v1/settings", json={"engine": "mirofish"})
    # Stored direct key remains, but MiroFish also needs Zep: clear path
    # is via a fresh DB state — here we assert the adapter itself.
    from app.engines.mirofish import MiroFishEngine
    import asyncio
    cfg = SimulationConfig(idea_title="X", idea_description="Y")
    try:
        asyncio.run(MiroFishEngine(None, None).start(cfg))
        raise AssertionError("should have raised")
    except Exception as e:
        assert getattr(e, "code", "") == "ENGINE_NOT_CONFIGURED"


def test_idempotency_no_second_run():
    idea = client.post("/api/v1/ideas", json={
        "title": "T", "description": "D"}).json()
    client.put("/api/v1/settings", json={"engine": "demo"})
    a = client.post("/api/v1/simulations", json={"idea_id": idea["id"]},
                    headers={"Idempotency-Key": "k-123"}).json()
    b = client.post("/api/v1/simulations", json={"idea_id": idea["id"]},
                    headers={"Idempotency-Key": "k-123"}).json()
    assert a["id"] == b["id"]


def test_seed_brief_does_not_invent_price():
    cfg = SimulationConfig(idea_title="Bottle",
                           idea_description="Tracks hydration.")
    brief = build_seed_brief(cfg)
    assert "not provided by the user" in brief
    assert "999" not in brief
    assert "Smart Water" not in build_requirement(cfg)  # requirement is generic
