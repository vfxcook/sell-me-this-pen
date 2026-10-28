"""Server-side settings: engine switch + keys.

Keys are stored ONLY here, on the server, encrypted with Fernet.
The encryption key comes from SETTINGS_SECRET env, or is generated
once into a 0600 file next to the database (dev only — production
must use a real secret manager). Keys are NEVER returned in full,
NEVER logged, and NEVER shipped in the app build. GET returns only
masked suffixes (last 4 chars) plus a per-engine configured flag.
An empty string on update means 'leave unchanged', never 'wipe'.
"""
import os
from cryptography.fernet import Fernet

ENGINES = ("mirofish", "direct", "demo")
_KEY_FILE = os.environ.get("SETTINGS_KEY_FILE", "./.settings_key")


def _fernet() -> Fernet:
    secret = os.environ.get("SETTINGS_SECRET")
    if secret:
        # Accept a raw Fernet key, or derive one deterministically.
        try:
            return Fernet(secret.encode())
        except Exception:
            import base64, hashlib
            return Fernet(base64.urlsafe_b64encode(
                hashlib.sha256(secret.encode()).digest()))
    if os.path.exists(_KEY_FILE):
        with open(_KEY_FILE, "rb") as f:
            return Fernet(f.read().strip())
    key = Fernet.generate_key()
    with open(_KEY_FILE, "wb") as f:
        f.write(key)
    os.chmod(_KEY_FILE, 0o600)
    return Fernet(key)


def encrypt(value: str | None) -> str | None:
    if not value:
        return None
    return _fernet().encrypt(value.encode()).decode()


def decrypt(value: str | None) -> str | None:
    if not value:
        return None
    return _fernet().decrypt(value.encode()).decode()


def mask(value: str | None) -> str | None:
    if not value:
        return None
    if len(value) <= 4:
        return "••••"
    return "••••" + value[-4:]


def engine_status(engine: str, row) -> dict:
    """What the selected engine still needs before a real run."""
    llm = bool(decrypt(row.llm_api_key_enc)) if row else False
    zep = bool(decrypt(row.zep_api_key_enc)) if row else False
    if engine == "mirofish":
        ready = llm and zep
        missing = [k for k, v in (("llm_api_key", llm),
                                  ("zep_api_key", zep)) if not v]
    elif engine == "direct":
        ready = llm
        missing = [] if llm else ["llm_api_key"]
    else:  # demo needs no keys, but is explicitly not a real run
        ready, missing = True, []
    return {"engine": engine, "ready": ready, "missing_keys": missing,
            "llm_configured": llm, "zep_configured": zep,
            "llm_api_key_masked": mask(decrypt(row.llm_api_key_enc)) if row else None,
            "zep_api_key_masked": mask(decrypt(row.zep_api_key_enc)) if row else None,
            "llm_base_url": row.llm_base_url if row else None,
            "llm_model_name": row.llm_model_name if row else None}
