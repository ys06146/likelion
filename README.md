# OraQ — web-first oral photo prototype

Flutter web + FastAPI + the bundled TensorFlow SavedModel. Create an account, upload a photo, view an image-level model score, revisit/compare/delete saved scans and edit your profile.

This experimental model is not a validated medical diagnosis. It does not detect individual teeth, gum health or plaque. Hard-coded findings and tooth highlights have been removed. A low score does not rule out a dental problem. Model accuracy requires separate validation using representative, consented data.

## Run locally

Tested: Flutter 3.41.4 / Dart 3.11.1, Python 3.11. From the repository root:

```sh
python -m venv .venv
# macOS/Linux: source .venv/bin/activate
# PowerShell: .\.venv\Scripts\Activate.ps1
python -m pip install -r backend/requirements.txt
python backend/setup_env.py
cd oral_health_ai
flutter pub get
flutter build web --release
cd ..
```

On Windows, use a short venv path if TensorFlow installation hits the path-length limit. Add `WEB_DIR=../oral_health_ai/build/web` to `backend/.env`, then:

```sh
python -m uvicorn main:app --app-dir backend --host 127.0.0.1 --port 8000
```

Open <http://127.0.0.1:8000>. `/health` checks the model and database; API docs are at `/docs`. The first analysis can be slower while TensorFlow warms up.

For hot reload, run the API and `flutter run -d chrome --web-port 7357` inside `oral_health_ai`. The client uses port 8000 locally. Select another API with `--dart-define=API_BASE_URL=https://your-api.example`. Requests time out after 25 seconds (90 seconds for analysis).

## Configuration and persistent data

See `backend/.env.example`. `setup_env.py` generates a random signing secret once and never overwrites existing configuration. Missing/placeholder secrets prevent startup. Keep `.env` private and the secret stable across restarts; rotating it invalidates sessions.

Relative paths resolve from `backend/`, independent of the shell working directory. Development uses the existing `backend/oraq_app.db`. Production requires `DATA_DIR` on a persistent mount or `DATABASE_URL`. PostgreSQL URLs use `postgresql+psycopg://...`; PostgreSQL integration is not tested and existing PostgreSQL schemas require separately managed migrations.

To retain existing SQLite accounts/scans, stop the old API, back up its database and copy it into the new persistent directory before startup. Empty volumes do not automatically inherit the old database. Back up the volume regularly; `docker compose down -v` deletes its data.

## Container deployment

Build Flutter web and create `backend/.env` as above, then:

```sh
docker compose up --build -d
docker compose logs -f oraq
```

The container serves API and web UI on port 8000, persists SQLite in the `oraq-data` volume and runs one worker to avoid duplicating the TensorFlow model. Compose binds to loopback. For public hosting, configure an HTTPS reverse proxy with request/rate limits. The image honors `PORT` (e.g. 7860 on Hugging Face); the host must mount persistent storage at `/data` or supply a database URL. Docker validation is included in CI; local execution needs Docker installed.

## GitHub Pages with a separate API

Pages hosts only the frontend. Deploy the updated API with durable storage first, then:

```sh
cd oral_health_ai
flutter build web --release --base-href /likelion/ --dart-define=API_BASE_URL=https://YOUR-API-HOST
```

Publish `build/web` through Pages. Set backend `CORS_ORIGINS=https://ys06146.github.io` (origin only, no path). A non-local build without `API_BASE_URL` calls its own origin; do not publish that build on Pages. Tracked `docs/` remains the previous published build until the production backend is ready. CI uploads a same-origin artifact and does not auto-deploy.

## Optional Google sign-in

Email/password works without Google credentials. The Google button is hidden unless the build receives `--dart-define=GOOGLE_CLIENT_ID=...`; set the same ID on the backend. Register the exact origin and redirect URI (including `/likelion/` on Pages) in the Google OAuth web client. The popup checks state, nonce, origin and source, and handles cancellation/timeouts. The API verifies Google's signed token. Never embed a client secret in Flutter. `GOOGLE_CLIENT_SECRET` is only needed for the separate backend redirect flow. Real-provider sign-in still needs testing with the deployment's registration. Native Google sign-in is not implemented.

## Tests

```sh
python -m unittest discover -s backend/tests -v
cd oral_health_ai
flutter analyze
flutter test
flutter build web --release
```

Backend tests isolate storage and exercise the real model with a synthetic image. Coverage includes image/body limits, invalid model output, authorization/ownership, reopening a DB connection, profile validation, Google verification mocks, CORS and startup configuration. Flutter tests cover small screens, long history, comparison, expired/offline sessions, profile cache consistency, upload limits, timeouts, decimal scores and OAuth response correlation.

Uploads accept JPEG, PNG or WebP up to 10 MiB and 20 megapixels. The server checks decoded bytes; failed analyses do not create records. Photo bytes are not saved by this application. Profile data and scores are stored. Before public launch, provide actual privacy/retention policies and validate the model; the prototype does not invent a terms agreement.

Android/iOS sources remain, but device permissions, native packaging and store readiness are outside this web-first verification.
