"""Create local config once without overwriting an existing secret."""
from pathlib import Path
import secrets

target = Path(__file__).resolve().parent / ".env"
try:
    with target.open("x", encoding="utf-8") as output:
        output.write("SECRET_KEY=" + secrets.token_urlsafe(48) + "\n")
        output.write("CORS_ORIGINS=http://localhost:7357,http://127.0.0.1:7357\n")
    print("Created backend/.env. Keep this file private and retain it across restarts.")
except FileExistsError:
    print("backend/.env already exists; left unchanged.")
