FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 APP_ENV=production DATA_DIR=/data WEB_DIR=/app/web PORT=8000
WORKDIR /app
RUN useradd --create-home --uid 1000 app && mkdir /data && chown app:app /data
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY --chown=app:app backend/ ./backend/
# Build flutter web first; see README.
COPY --chown=app:app oral_health_ai/build/web/ ./web/
USER app
EXPOSE 8000
HEALTHCHECK --start-period=120s --interval=30s --timeout=5s CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:'+os.getenv('PORT','8000')+'/health', timeout=4)" || exit 1
CMD ["sh", "-c", "exec uvicorn main:app --app-dir backend --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]
