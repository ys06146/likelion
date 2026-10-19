"""Environment configuration shared by local runs, tests and containers."""
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")
PRODUCTION = os.getenv("APP_ENV", "development") == "production"
SECRET_KEY = os.getenv("SECRET_KEY", "")
if len(SECRET_KEY) < 32 or SECRET_KEY.startswith(("change-this", "YOUR_SUPER")):
    raise RuntimeError("Set SECRET_KEY to a random value of at least 32 characters in backend/.env or the environment.")

def resolve_path(value, base=BASE_DIR):
    path = Path(value).expanduser()
    return path if path.is_absolute() else base / path

MODEL_PATH = resolve_path(os.getenv("MODEL_PATH", "model_exp03b_saved"))
database_url = os.getenv("DATABASE_URL")
data_dir = os.getenv("DATA_DIR")
if PRODUCTION and not database_url and not data_dir:
    raise RuntimeError("Production requires DATABASE_URL or DATA_DIR on persistent storage.")
DATA_DIR = resolve_path(data_dir) if data_dir else BASE_DIR
if not database_url:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
DATABASE_URL = database_url or f"sqlite:///{(DATA_DIR / 'oraq_app.db').as_posix()}"
CORS_ORIGINS = [origin.strip() for origin in os.getenv(
    "CORS_ORIGINS", "" if PRODUCTION else "http://localhost:7357,http://127.0.0.1:7357"
).split(",") if origin.strip()]
if "*" in CORS_ORIGINS:
    raise RuntimeError("CORS_ORIGINS must list explicit origins, not '*'.")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000
WEB_DIR = resolve_path(os.environ["WEB_DIR"]) if os.getenv("WEB_DIR") else None
