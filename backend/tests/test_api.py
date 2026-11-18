"""Run from the repository root: python -m unittest discover -s backend/tests -v."""
import io
import os
import sys
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

_storage = tempfile.TemporaryDirectory(prefix="oraq-tests-")
os.environ["DATA_DIR"] = _storage.name
os.environ["SECRET_KEY"] = "test-only-secret-" + "x" * 48
os.environ["APP_ENV"] = "development"
os.environ["CORS_ORIGINS"] = "http://localhost:7357"
os.environ.pop("DATABASE_URL", None)
os.environ.pop("WEB_DIR", None)
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import main
import numpy as np
from PIL import Image
from fastapi.testclient import TestClient
from jose import jwt

class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(main.app, raise_server_exceptions=False)
        cls.client.__enter__()
        stream = io.BytesIO()
        Image.new("RGB", (224, 224), (180, 140, 130)).save(stream, "PNG")
        cls.image = stream.getvalue()

    def setUp(self):
        with main.SessionLocal() as db:
            db.query(main.Scan).delete()
            db.query(main.User).delete()
            db.commit()
        self.headers = self.account("test@example.com")

    def account(self, email):
        result = self.client.post("/auth/signup", json={
            "email": email, "password": "example-password", "full_name": "Test User"})
        self.assertEqual(result.status_code, 200, result.text)
        login = self.client.post("/auth/login", json={"email": email, "password": "example-password"})
        self.assertEqual(login.status_code, 200, login.text)
        return {"Authorization": "Bearer " + login.json()["access_token"]}

    def upload(self, data=None, filename="image.png"):
        return self.client.post("/scans/predict", headers=self.headers,
            files={"image": (filename, self.image if data is None else data, "application/octet-stream")})

    def test_real_model_round_trip_and_ownership(self):
        self.assertIsNotNone(main.model)
        prediction = self.upload()
        self.assertEqual(prediction.status_code, 200, prediction.text)
        body = prediction.json()
        self.assertTrue(0 <= body["prob_percent"] <= 100)
        self.assertEqual(body["details"], {})
        self.assertIn("not assessed", body["assessment_scope"])
        scan_id = body["scan_id"]
        history = self.client.get("/scans/history", headers=self.headers).json()
        self.assertEqual(history["total_scans"], 1)
        self.assertEqual(history["recent_scans"][0]["scan_id"], scan_id)
        detail = self.client.get(f"/scans/detail/{scan_id}", headers=self.headers)
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.json()["details"], {})
        other = self.account("other@example.com")
        self.assertEqual(self.client.get(f"/scans/detail/{scan_id}", headers=other).status_code, 404)
        self.assertEqual(self.client.delete(f"/scans/delete/{scan_id}", headers=other).status_code, 404)
        self.assertEqual(self.client.delete(f"/scans/delete/{scan_id}", headers=self.headers).status_code, 200)
        self.assertEqual(self.client.get("/scans/history", headers=self.headers).json()["total_scans"], 0)

    def test_corrupt_empty_and_unsupported_images(self):
        for data in [b"not an image", b""]:
            self.assertEqual(self.upload(data).status_code, 400)
        gif = io.BytesIO()
        Image.new("RGB", (2, 2)).save(gif, "GIF")
        self.assertEqual(self.upload(gif.getvalue()).status_code, 415)
        self.assertEqual(self.client.get("/scans/history", headers=self.headers).json()["total_scans"], 0)

    def test_file_size_limit(self):
        self.assertEqual(self.upload(b"x" * (main.MAX_IMAGE_BYTES + 1)).status_code, 413)

    def test_chunked_body_limit(self):
        chunks = (b"x" * (1024 * 1024) for _ in range(12))
        response = self.client.post("/scans/predict", headers={
            **self.headers, "Content-Type": "application/octet-stream"}, content=chunks)
        self.assertEqual(response.status_code, 413)

    def test_pixel_limit(self):
        with patch.object(main, "MAX_IMAGE_PIXELS", 100):
            self.assertEqual(self.upload().status_code, 413)

    def test_model_failure_returns_503_without_saving(self):
        with patch.object(main, "model", None):
            self.assertEqual(self.upload().status_code, 503)
            self.assertEqual(self.client.get("/health").status_code, 503)
        class InvalidModel:
            def predict(self, *args, **kwargs): return np.array([[float("nan")]])
        with patch.object(main, "model", InvalidModel()):
            self.assertEqual(self.upload().status_code, 503)
        self.assertEqual(self.client.get("/scans/history", headers=self.headers).json()["total_scans"], 0)

    def test_auth_and_expired_token(self):
        self.assertEqual(self.client.get("/scans/history").status_code, 401)
        token = jwt.encode({"sub": "test@example.com", "exp": 1}, main.SECRET_KEY, algorithm=main.ALGORITHM)
        self.assertEqual(self.client.get("/users/me", headers={"Authorization": "Bearer " + token}).status_code, 401)

    def test_profile_validation_and_storage(self):
        self.assertEqual(self.client.patch("/users/me", headers=self.headers, json={"age": -1}).status_code, 422)
        self.assertEqual(self.client.patch("/users/me", headers=self.headers,
            json={"age": 29, "smoker": True, "blood_type": None}).status_code, 200)
        profile = self.client.get("/users/me", headers=self.headers).json()
        self.assertEqual(profile["age"], 29)
        self.assertTrue(profile["smoker"])
        self.assertIsNone(profile["blood_type"])

    def test_file_database_survives_connection_restart(self):
        main.engine.dispose()
        with sqlite3.connect(Path(_storage.name) / "oraq_app.db") as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM users").fetchone()[0], 1)
        self.assertEqual(self.client.get("/users/me", headers=self.headers).status_code, 200)

    def test_legacy_findings_are_not_returned(self):
        with main.SessionLocal() as db:
            user = db.query(main.User).filter_by(email="test@example.com").one()
            scan = main.Scan(owner_id=user.id, date="2026-10-18", prob_percent=20, level="Normal",
                details=json.dumps({"gums": "Healthy", "plaque": "Moderate"}), recommendations="[]")
            db.add(scan); db.commit(); scan_id = scan.id
        result = self.client.get(f"/scans/detail/{scan_id}", headers=self.headers).json()
        self.assertEqual(result["details"], {})
        self.assertNotIn("Healthy", json.dumps(result))

    def test_password_and_bad_login_inputs(self):
        for password in ["short", "a" * 73, "한" * 25]:
            response = self.client.post("/auth/signup", json={
                "email": "new@example.com", "password": password, "full_name": "Test"})
            self.assertEqual(response.status_code, 422)
        self.assertEqual(self.client.post("/auth/login",
            json={"email": {"bad": "shape"}, "password": ["bad"]}).status_code, 400)
        self.assertEqual(self.client.post("/auth/login",
            json={"email": "test@example.com", "password": "wrong"}).status_code, 400)

    def test_cors_and_readiness(self):
        self.assertEqual(self.client.get("/health").status_code, 200)
        for origin, expected in [("http://localhost:7357", 200), ("https://unexpected.example", 400)]:
            response = self.client.options("/auth/login", headers={
                "Origin": origin, "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type"})
            self.assertEqual(response.status_code, expected)

    def test_google_signature_and_email_checks(self):
        with patch.object(main, "GOOGLE_CLIENT_ID", "test-client"), patch.object(
            main.google_id_token, "verify_oauth2_token", side_effect=ValueError("invalid")):
            self.assertEqual(self.client.post("/auth/google/mobile", json={"id_token": "bad"}).status_code, 401)
        with patch.object(main, "GOOGLE_CLIENT_ID", "test-client"), patch.object(
            main.google_id_token, "verify_oauth2_token",
            return_value={"email": "google@example.com", "email_verified": True, "name": "Google User"}):
            response = self.client.post("/auth/google/mobile", json={"id_token": "mock-verified"})
            self.assertEqual(response.status_code, 200, response.text)
            self.assertEqual(response.json()["email"], "google@example.com")

def tearDownModule():
    ApiTests.client.__exit__(None, None, None)
    main.engine.dispose()
    _storage.cleanup()

if __name__ == "__main__":
    unittest.main()
