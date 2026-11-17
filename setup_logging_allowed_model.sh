#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CONFIGURATION — Update these values for your environment
# ==============================================================================
PROJECT_ID="${PROJECT_ID:-YOUR_PROJECT_ID}"
VERTEX_LOCATION="${VERTEX_LOCATION:-global}"      # Endpoint Antigravity uses: "global" or e.g. "us-central1"
BQ_DATASET="${BQ_DATASET:-antigravity_logs}"
BQ_TABLE="${BQ_TABLE:-gemini_req_resp_logs}"

# Allowed models: Gemini 4 Hydrogen, Gemini 3.8 Flash, and below
ALLOWED_MODELS=(
  "gemini-4-hydrogen"
  "gemini-3.8-flash"
  "gemini-3.7-flash"
  "gemini-3.5-flash"
  "gemini-3.5-flash-lite"
  "gemini-3.1-flash-lite"
  "gemini-3.1-pro-preview"
  "gemini-2.5-pro"
  "gemini-2.5-flash"
  "gemini-2.5-flash-lite"
)
# ==============================================================================

if [ "${PROJECT_ID}" = "YOUR_PROJECT_ID" ]; then
  echo "Error: Set PROJECT_ID before running this script." >&2
  exit 1
fi

echo "==> 1. Enabling required APIs..."
gcloud services enable \
  aiplatform.googleapis.com \
  bigquery.googleapis.com \
  orgpolicy.googleapis.com \
  --project="${PROJECT_ID}"

echo "==> 2. Setting Org Policy (constraints/vertexai.allowedModels) on project..."
POLICY_FILE=$(mktemp /tmp/vertexai_allowed_models.XXXXXX.yaml)
{
  echo "name: projects/${PROJECT_ID}/policies/vertexai.allowedModels"
  echo "spec:"
  echo "  rules:"
  echo "    - values:"
  echo "        allowedValues:"
  for MODEL in "${ALLOWED_MODELS[@]}"; do
    echo "          - is:publishers/google/models/${MODEL}:predict"
  done
} > "${POLICY_FILE}"

gcloud org-policies set-policy "${POLICY_FILE}" --project="${PROJECT_ID}"
rm -f "${POLICY_FILE}"

echo "==> 3. Creating BigQuery dataset for request-response logs..."
if ! bq --project_id="${PROJECT_ID}" show "${BQ_DATASET}" >/dev/null 2>&1; then
  bq --project_id="${PROJECT_ID}" mk --dataset "${PROJECT_ID}:${BQ_DATASET}"
fi

echo "==> 4. Enabling Vertex AI Request-Response Logging to BigQuery..."
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ "${VERTEX_LOCATION}" = "global" ]; then
  VERTEX_ENDPOINT="https://aiplatform.googleapis.com"
else
  VERTEX_ENDPOINT="https://${VERTEX_LOCATION}-aiplatform.googleapis.com"
fi

BQ_URI="bq://${PROJECT_ID}.${BQ_DATASET}.${BQ_TABLE}"

for MODEL in "${ALLOWED_MODELS[@]}"; do
  echo "   -> Configuring logging for ${MODEL} (${VERTEX_LOCATION})..."
  curl -sS -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    "${VERTEX_ENDPOINT}/v1beta1/projects/${PROJECT_ID}/locations/${VERTEX_LOCATION}/publishers/google/models/${MODEL}:setPublisherModelConfig" \
    -d "{
      \"publisherModelConfig\": {
        \"loggingConfig\": {
          \"enabled\": true,
          \"samplingRate\": 1.0,
          \"bigqueryDestination\": {
            \"outputUri\": \"${BQ_URI}\"
          },
          \"enableOtelLogging\": true
        }
      }
    }" | python3 -m json.tool
done

echo "==> Setup complete! Allow a few minutes for policy and logging propagation."
