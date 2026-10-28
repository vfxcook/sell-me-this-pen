from ..settings_store import decrypt
from .demo import DemoEngine
from .direct import DirectEngine
from .mirofish import MiroFishEngine


def get_engine(name: str, row):
    if name == "mirofish":
        return MiroFishEngine(decrypt(row.llm_api_key_enc) if row else None,
                              decrypt(row.zep_api_key_enc) if row else None)
    if name == "direct":
        return DirectEngine(decrypt(row.llm_api_key_enc) if row else None,
                            row.llm_base_url if row else None,
                            row.llm_model_name if row else None)
    return DemoEngine()
