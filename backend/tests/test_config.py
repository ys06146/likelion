import os
import sys
import subprocess
import unittest
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]

class ConfigTests(unittest.TestCase):
    def run_config(self, **values):
        env = dict(os.environ, PYTHONPATH=str(BACKEND), PYTHON_DOTENV_DISABLED="1")
        for key in ["SECRET_KEY", "DATA_DIR", "DATABASE_URL", "APP_ENV", "CORS_ORIGINS"]:
            env.pop(key, None)
        env.update(values)
        return subprocess.run([sys.executable, "-c", "import config"], env=env,
            capture_output=True, text=True, timeout=15)

    def test_missing_secret_fails_closed(self):
        result = self.run_config()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SECRET_KEY", result.stderr)

    def test_production_requires_storage(self):
        result = self.run_config(SECRET_KEY="x" * 48, APP_ENV="production")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("persistent storage", result.stderr)

    def test_database_url_and_explicit_origins(self):
        result = self.run_config(SECRET_KEY="x" * 48, APP_ENV="production",
            DATABASE_URL="postgresql+psycopg://example/db", CORS_ORIGINS="https://app.example")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_wildcard_cors_is_rejected(self):
        result = self.run_config(SECRET_KEY="x" * 48, CORS_ORIGINS="*")
        self.assertNotEqual(result.returncode, 0)
