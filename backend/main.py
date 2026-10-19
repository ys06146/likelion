import os
import io
import json
import logging
import warnings
from threading import Lock
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import FastAPI, File, UploadFile, Query, HTTPException, Depends, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import create_engine, Column, Integer, String, Float, ForeignKey, Text, Boolean, inspect, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from sqlalchemy.exc import IntegrityError
import numpy as np
import tensorflow as tf
from tensorflow import keras
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, EmailStr, Field, field_validator
from starlette.concurrency import run_in_threadpool
from fastapi.staticfiles import StaticFiles

from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

from authlib.integrations.starlette_client import OAuth
from starlette.middleware.sessions import SessionMiddleware
from config import (
    SECRET_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, MODEL_PATH,
    DATABASE_URL, CORS_ORIGINS, MAX_IMAGE_BYTES, MAX_IMAGE_PIXELS, WEB_DIR, PRODUCTION,
)
from upload_limit import UploadLimitMiddleware

# --- 1. Configuration & Security ---
logger = logging.getLogger("oraq")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# --- 2. OAuth & AI Model Loading ---
oauth = OAuth()
oauth.register(
    name='google',
    client_id=GOOGLE_CLIENT_ID,
    client_secret=GOOGLE_CLIENT_SECRET,
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'}
)

os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
inference_lock = Lock()

try:
    model = keras.Sequential([
        keras.layers.TFSMLayer(str(MODEL_PATH), call_endpoint='serving_default')
    ])
except Exception as e:
    print(f"Model Load Failed: {e}")
    model = None

# --- 3. Database Configuration ---
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {},
    pool_pre_ping=True,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True) # 구글 유저를 위해 Null 허용
    full_name = Column(String)
    age = Column(Integer, nullable=True)
    gender = Column(String, nullable=True)
    blood_type = Column(String, nullable=True)
    smoker = Column(Boolean, nullable=True, default=False)
    alcohol = Column(Boolean, nullable=True, default=False)
    scans = relationship("Scan", back_populates="owner")

class Scan(Base):
    __tablename__ = "scans"
    id = Column(Integer, primary_key=True, index=True)
    date = Column(String, nullable=False)
    prob_percent = Column(Float, nullable=False)
    level = Column(String, nullable=False)
    summary = Column(String)
    details = Column(Text) # JSON string
    recommendations = Column(Text) # JSON string
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="scans")

Base.metadata.create_all(bind=engine)


def migrate_sqlite_user_columns():
    if "sqlite" not in DATABASE_URL:
        return
    try:
        inspector = inspect(engine)
        cols = {c["name"] for c in inspector.get_columns("users")}
        with engine.begin() as conn:
            if "smoker" not in cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN smoker BOOLEAN DEFAULT 0"))
            if "alcohol" not in cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN alcohol BOOLEAN DEFAULT 0"))
    except Exception as e:
        print(f"User table migration: {e}")


migrate_sqlite_user_columns()

# --- 4. Utilities & Dependencies ---
def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def extract_login_credentials(request: Request):
    content_type = request.headers.get("content-type", "").lower()
    email = None
    password = None

    if "application/json" in content_type:
        try:
            payload = await request.json()
        except json.JSONDecodeError:
            payload = {}

        if isinstance(payload, dict):
            email = payload.get("email") or payload.get("username")
            password = payload.get("password")
    else:
        form = await request.form()
        email = form.get("username") or form.get("email")
        password = form.get("password")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password are required.")

    return email, password

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(status_code=401, detail="Could not validate credentials")
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None: raise credentials_exception
    except JWTError: raise credentials_exception
    user = db.query(User).filter(User.email == email).first()
    if user is None: raise credentials_exception
    return user

# --- 5. AI Image Preprocessing ---
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS
def preprocess_image(image_bytes):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(image_bytes)) as source:
                if source.format not in {"JPEG", "PNG", "WEBP"}:
                    raise HTTPException(status_code=415, detail="Choose a JPEG, PNG or WebP image.")
                if source.width * source.height > MAX_IMAGE_PIXELS:
                    raise HTTPException(status_code=413, detail="Image exceeds the 20 megapixel limit.")
                source.load()
                img = ImageOps.exif_transpose(source).convert("RGB").resize((224, 224))
    except (Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(status_code=413, detail="Image exceeds the 20 megapixel limit.")
    except (UnidentifiedImageError, OSError, ValueError):
        raise HTTPException(status_code=400, detail="The file is not a readable image.")
    x = np.array(img).astype(np.float32) / 255.0
    x = (x - MEAN) / STD
    return np.expand_dims(x, axis=0)

def infer_probability(contents):
    if model is None:
        raise HTTPException(status_code=503, detail="Image analysis is temporarily unavailable. Please try again later.")
    x = preprocess_image(contents)
    try:
        with inference_lock:
            predictions = model.predict(x, verbose=0)
        output = next(iter(predictions.values())) if isinstance(predictions, dict) else predictions
        values = np.asarray(output).flatten()
        if values.size != 1 or not np.isfinite(values[0]) or not 0 <= values[0] <= 1:
            raise ValueError("Expected one finite probability.")
        return float(values[0])
    except Exception:
        logger.exception("Model inference failed")
        raise HTTPException(status_code=503, detail="Image analysis is temporarily unavailable. Please try again later.")

ANALYSIS_SCOPE = "Image-level model score only; individual teeth, gums and plaque are not assessed."
GENERAL_GUIDANCE = [
    "This experimental score is not a medical diagnosis.",
    "Consult a dental professional about symptoms or concerns, regardless of the score.",
]

# --- 6. Pydantic Schemas ---
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    full_name: str = Field(min_length=1, max_length=100)

    @field_validator("password")
    @classmethod
    def password_length(cls, value):
        if len(value.encode("utf-8")) > 72:
            raise ValueError("Password must be at most 72 UTF-8 bytes.")
        return value

    @field_validator("full_name")
    @classmethod
    def name_not_blank(cls, value):
        if not value.strip():
            raise ValueError("Name is required.")
        return value.strip()

class Token(BaseModel):
    access_token: str
    token_type: str


class UserProfileOut(BaseModel):
    full_name: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    blood_type: Optional[str] = None
    smoker: bool = False
    alcohol: bool = False


class LoginTokenResponse(BaseModel):
    access_token: str
    token_type: str
    email: str
    profile: UserProfileOut


def user_to_profile_out(user: User) -> UserProfileOut:
    return UserProfileOut(
        full_name=user.full_name,
        age=user.age,
        gender=user.gender,
        blood_type=user.blood_type,
        smoker=bool(user.smoker) if user.smoker is not None else False,
        alcohol=bool(user.alcohol) if user.alcohol is not None else False,
    )


class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    age: Optional[int] = Field(default=None, ge=1, le=120)
    gender: Optional[str] = None
    blood_type: Optional[str] = None
    smoker: Optional[bool] = None
    alcohol: Optional[bool] = None

class GoogleMobileLoginRequest(BaseModel):
    id_token: str
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None

# --- 7. API Setup ---
app = FastAPI(title="OraQ Oral Health AI API")
app.add_middleware(SessionMiddleware, secret_key=SECRET_KEY, https_only=PRODUCTION)
app.add_middleware(UploadLimitMiddleware, max_bytes=MAX_IMAGE_BYTES + 64 * 1024)
app.add_middleware(CORSMiddleware, allow_origins=CORS_ORIGINS, allow_methods=["GET", "POST", "PATCH", "DELETE"], allow_headers=["Authorization", "Content-Type"])

@app.get("/health")
def health():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception:
        raise HTTPException(status_code=503, detail="Database unavailable.")
    if model is None:
        raise HTTPException(status_code=503, detail="Model unavailable.")
    return {"status": "ok", "model_loaded": True}

# --- 8. API Endpoints ---

# [AUTH] Signup
@app.post("/auth/signup")
def signup(user_in: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user_in.email).first():
        raise HTTPException(status_code=400, detail="Email already registered.")
    new_user = User(
        email=user_in.email,
        hashed_password=pwd_context.hash(user_in.password),
        full_name=user_in.full_name
    )
    db.add(new_user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Email already registered.")
    return {"message": "Signup successful"}

# [AUTH] Login
@app.post("/auth/login", response_model=LoginTokenResponse)
async def login(request: Request, db: Session = Depends(get_db)):
    email, password = await extract_login_credentials(request)
    if not isinstance(email, str) or not isinstance(password, str):
        raise HTTPException(status_code=400, detail="Email and password must be text.")
    user = db.query(User).filter(User.email == email).first()
    if len(password.encode("utf-8")) > 72:
        raise HTTPException(status_code=400, detail="Incorrect email or password.")
    if not user or not user.hashed_password or not await run_in_threadpool(pwd_context.verify, password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect email or password.")
    db.refresh(user)
    access_token = create_access_token(data={"sub": user.email})
    return LoginTokenResponse(
        access_token=access_token,
        token_type="bearer",
        email=user.email,
        profile=user_to_profile_out(user),
    )

# [GOOGLE AUTH] Google Login
@app.get("/auth/google/login")
async def google_login(request: Request):
    if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
        raise HTTPException(status_code=503, detail="Google login is not configured.")
    redirect_uri = request.url_for('google_auth') 
    return await oauth.google.authorize_redirect(request, redirect_uri)

# [GOOGLE AUTH] Google Callback
@app.get("/auth/google/callback", name="google_auth")
async def google_auth(request: Request, db: Session = Depends(get_db)):
    try:
        token = await oauth.google.authorize_access_token(request)
    except Exception:
        raise HTTPException(status_code=400, detail="Google authentication failed")
    
    user_info = token.get('userinfo') or {}
    if not user_info.get("email") or not user_info.get("email_verified"):
        raise HTTPException(status_code=401, detail="A verified Google email is required.")
    email = user_info['email']

    user = db.query(User).filter(User.email == email).first()
    if not user:
        user = User(
            email=email,
            full_name=user_info.get('name'),
            hashed_password=None
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer", "method": "google"}

@app.post("/auth/google/mobile", response_model=LoginTokenResponse)
async def google_mobile_login(payload: GoogleMobileLoginRequest, db: Session = Depends(get_db)):
    if not GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Google login is not configured.")

    try:
        idinfo = await run_in_threadpool(google_id_token.verify_oauth2_token,
            payload.id_token,
            google_requests.Request(),
            audience=GOOGLE_CLIENT_ID,
        )
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid Google ID token")
    except Exception:
        raise HTTPException(status_code=503, detail="Google verification is temporarily unavailable.")

    token_email = idinfo.get("email")
    if not token_email or (payload.email and token_email.lower() != payload.email.lower()):
        raise HTTPException(status_code=400, detail="Email mismatch between token and request")

    if not idinfo.get("email_verified", False):
        raise HTTPException(status_code=400, detail="Google email not verified")

    user = db.query(User).filter(User.email == token_email).first()
    if not user:
        user = User(
            email=token_email,
            full_name=payload.display_name or idinfo.get("name"),
            hashed_password=None
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    db.refresh(user)
    access_token = create_access_token(data={"sub": user.email})
    return LoginTokenResponse(
        access_token=access_token,
        token_type="bearer",
        email=user.email,
        profile=user_to_profile_out(user),
    )

# 1. AI Diagnosis (predictRisk)
@app.post("/scans/predict")
async def predict_risk(image: UploadFile = File(...), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    contents = await image.read(MAX_IMAGE_BYTES + 1)
    await image.close()
    if len(contents) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image upload exceeds the 10 MB limit.")
    p = await run_in_threadpool(infer_probability, contents)

    prob_percent = round(p * 100, 2)
    level = "Risk" if p >= 0.7 else ("Caution" if p >= 0.3 else "Normal")
    summary = f"{level} model score"
    
    details_data = {}
    recs_data = GENERAL_GUIDANCE

    new_scan = Scan(
        owner_id=current_user.id,
        date=datetime.now().strftime("%Y-%m-%d %H:%M"),
        prob_percent=prob_percent,
        level=level,
        summary=summary,
        details=json.dumps(details_data),
        recommendations=json.dumps(recs_data)
    )
    db.add(new_scan)
    db.commit()
    
    return {"scan_id": new_scan.id, "prob_percent": prob_percent, "level": level, "summary": summary, "details": details_data, "recommendations": recs_data, "assessment_scope": ANALYSIS_SCOPE}

# 2. History Lookup (getHistory)
@app.get("/scans/history")
async def get_history(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(Scan).filter(Scan.owner_id == current_user.id).order_by(Scan.id.desc()).all()
    recent_scans = [{"scan_id": r.id, "date": r.date, "prob_percent": r.prob_percent, "level": r.level, "summary": r.summary} for r in rows]
    return {"total_scans": len(rows), "recent_scans": recent_scans}

# 3. Detail View (getScanDetail)
@app.get("/scans/detail/{scan_id}")
async def get_scan_detail(scan_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    scan = db.query(Scan).filter(Scan.id == scan_id, Scan.owner_id == current_user.id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    # Legacy records contain fabricated per-tooth/gum/plaque findings. Never return them.
    return {"scan_id": scan.id, "probability": scan.prob_percent, "status_labels": scan.level, "details": {}, "advice_list": GENERAL_GUIDANCE, "assessment_scope": ANALYSIS_SCOPE}

# 4. Delete Record (deleteScan)
@app.delete("/scans/delete/{scan_id}")
async def delete_scan(scan_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    scan = db.query(Scan).filter(Scan.id == scan_id, Scan.owner_id == current_user.id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    db.delete(scan)
    db.commit()
    return {"success_status": True, "message": "Record deleted successfully"}

# [USER] Profile Management
@app.get("/users/me")
async def read_profile(current_user: User = Depends(get_current_user)):
    return {
        "full_name": current_user.full_name,
        "age": current_user.age,
        "gender": current_user.gender,
        "blood_type": current_user.blood_type,
        "smoker": bool(current_user.smoker) if current_user.smoker is not None else False,
        "alcohol": bool(current_user.alcohol) if current_user.alcohol is not None else False,
    }


@app.patch("/users/me")
async def update_profile(user_update: UserUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    raw = (
        user_update.model_dump(exclude_unset=True)
        if hasattr(user_update, "model_dump")
        else user_update.dict(exclude_unset=True)
    )
    for key, value in raw.items():
        setattr(current_user, key, value)
    db.add(current_user)
    db.commit()
    db.refresh(current_user)
    return {"message": "Profile updated"}

if WEB_DIR is not None:
    app.mount("/", StaticFiles(directory=str(WEB_DIR), html=True), name="web")
