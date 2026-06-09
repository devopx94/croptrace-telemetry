import json
import logging
import os
import signal
from datetime import datetime
from typing import Optional

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        }
        return json.dumps(log_record)


logger = logging.getLogger("croptrace-api")
handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger.addHandler(handler)
logger.setLevel(os.getenv("LOG_LEVEL", "INFO"))


APP_NAME = os.getenv("APP_NAME", "croptrace-api")
DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "croptrace")
DB_USER = os.getenv("DB_USER", "croptrace")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
MONOLITH_API_KEY = os.getenv("MONOLITH_API_KEY", "")


app = FastAPI(title=APP_NAME)


class TelemetryRequest(BaseModel):
    facility_id: str = Field(..., min_length=1)
    timestamp: str
    crop_type: str = Field(..., min_length=1)
    weight_kg: float = Field(..., gt=0)
    quality_rating: int = Field(..., ge=1, le=5)


def get_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=3,
    )


def init_db():
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS telemetry (
                    id SERIAL PRIMARY KEY,
                    facility_id VARCHAR(100) NOT NULL,
                    event_timestamp VARCHAR(100) NOT NULL,
                    crop_type VARCHAR(100) NOT NULL,
                    weight_kg NUMERIC NOT NULL,
                    quality_rating INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """
            )


@app.on_event("startup")
def startup_event():
    logger.info("starting CropTrace API")
    init_db()


@app.on_event("shutdown")
def shutdown_event():
    logger.info("gracefully shutting down CropTrace API")


@app.get("/")
def root():
    return {"service": APP_NAME, "status": "running"}


@app.get("/api/v1/health")
def health():
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return {"status": "ok", "database": "healthy"}
    except Exception as exc:
        logger.error(f"database health check failed: {str(exc)}")
        raise HTTPException(status_code=503, detail="database unhealthy")


@app.post("/api/v1/telemetry", status_code=201)
def create_telemetry(payload: TelemetryRequest):
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO telemetry (
                        facility_id,
                        event_timestamp,
                        crop_type,
                        weight_kg,
                        quality_rating
                    )
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id;
                    """,
                    (
                        payload.facility_id,
                        payload.timestamp,
                        payload.crop_type,
                        payload.weight_kg,
                        payload.quality_rating,
                    ),
                )
                telemetry_id = cur.fetchone()[0]

        logger.info(
            f"telemetry stored facility_id={payload.facility_id} crop_type={payload.crop_type}"
        )
        return {"id": telemetry_id, "status": "stored"}

    except Exception as exc:
        logger.error(f"failed to store telemetry: {str(exc)}")
        raise HTTPException(status_code=500, detail="failed to store telemetry")
