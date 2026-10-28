from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from .db import init_db
from .routers import ideas, settings, simulations

app = FastAPI(title="Sell Me This Pen API", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"],
                   allow_methods=["*"], allow_headers=["*"])


@app.on_event("startup")
def startup():
    init_db()


@app.exception_handler(Exception)
async def _err(request: Request, exc: Exception):
    # Never leak tracebacks to clients (MiroFish does; we must not).
    return JSONResponse(status_code=500, content={"error": {
        "code": "INTERNAL_ERROR", "message": "Something went wrong.",
        "retryable": True}})


@app.get("/health")
def health():
    return {"status": "ok", "service": "sell-me-this-pen-api"}


app.include_router(settings.router)
app.include_router(ideas.router)
app.include_router(simulations.router)
