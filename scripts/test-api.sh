#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:8080}"

echo "Testing health endpoint..."
curl -s "${BASE_URL}/api/v1/health" | jq .

echo "Posting telemetry..."
curl -s -X POST "${BASE_URL}/api/v1/telemetry"   -H "Content-Type: application/json"   -d '{
    "facility_id": "FAC-001",
    "timestamp": "2026-06-09T10:00:00Z",
    "crop_type": "Tea",
    "weight_kg": 1250.5,
    "quality_rating": 5
  }' | jq .
