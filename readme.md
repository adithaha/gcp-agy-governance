# Antigravity PAYG AI Governance

This guide walks through executing [setup_logging_allowed_model.sh](./setup_logging_allowed_model.sh) to configure Vertex AI model allowlisting and BigQuery request-response logging for Google Antigravity Pay-As-You-Go (PAYG).

---

## Overview: What This Configuration Does

This setup establishes baseline governance, cost control, and visibility for teams using Google Antigravity in Pay-As-You-Go mode:

1.  **Limit Project to Approved Models**
    *   **Business Need:** Prevent unexpected AI spend and ensure teams only use vetted, approved models.
    *   **Outcome:** Developers can only run approved models (such as Gemini 4 Hydrogen, Gemini 3.8 Flash, and earlier versions). Newer, higher-cost, or unapproved third-party models are automatically blocked at the project level.
2.  **Enable Prompt & Response Logging**
    *   **Business Need:** Maintain a complete audit trail for security, compliance, and internal review.
    *   **Outcome:** Every prompt sent by a developer and every response returned by the AI is automatically recorded in your organization's own BigQuery data warehouse, giving security and compliance teams full ownership and visibility of AI interactions.
3.  **Token Usage Query**
    *   **Business Need:** Understand AI adoption, track consumption by team member, and forecast costs.
    *   **Outcome:** Using the included [token usage query](./sql/token-usage-user.sql), FinOps and engineering leaders can generate daily reports showing how many requests and tokens each user consumes per model—helping attribute costs, spot power users, and measure ROI.

---

## 1. Prerequisites

*   **Tools:** `gcloud` CLI, `bq` CLI, `curl`, and `python3` (available in Google Cloud Shell).
*   **IAM Permissions Required:**
    *   `roles/orgpolicy.policyAdmin` — Set and view `constraints/vertexai.allowedModels` *(must be granted at the Organization or Folder level)*
    *   `roles/aiplatform.admin` — Configure and verify Vertex AI request-response logging (`setPublisherModelConfig` / `fetchPublisherModelConfig`)
    *   `roles/bigquery.admin` — Create and manage the `antigravity_logs` BigQuery dataset
    *   `roles/serviceusage.serviceUsageAdmin` — Enable required APIs (`aiplatform`, `bigquery`, `orgpolicy`)
*   **Authentication:**
    ```bash
    gcloud auth login
    gcloud config set project YOUR_PROJECT_ID
    ```

### 
---

## 2. Execution Steps

1.  Make the provisioning script executable:
    ```bash
    chmod +x setup_logging_allowed_model.sh
    ```
2.  Export your environment variables (or edit the defaults at the top of `setup_logging_allowed_model.sh`):
    ```bash
    export PROJECT_ID="YOUR_PROJECT_ID"
    export VERTEX_LOCATION="global"       # Match the endpoint Antigravity uses ("global" or e.g. "us-central1")
    ```
3.  Run the script:
    ```bash
    # What the Script Provisions
    # 1.  Enables `aiplatform.googleapis.com`, `bigquery.googleapis.com`, and `orgpolicy.googleapis.com`.
    # 2.  Applies `constraints/vertexai.allowedModels` to allow only **Gemini 4 Hydrogen (`gemini-4-hydrogen`)**, **Gemini 3.8 Flash (`gemini-3.8-flash`)**, and earlier Gemini models.
    # 3.  Creates the BigQuery dataset `antigravity_logs`.
    # 4.  Enables Vertex AI Request-Response Logging (`samplingRate: 1.0`) to BigQuery for every allowed Gemini model.

    ./setup_logging_allowed_model.sh
    ```

---

## 3. Verification

Allow a few minutes for Org Policy and Vertex AI logging configurations to propagate, then run the checks below.

### 3.1 Verify Organization Policy (`vertexai.allowedModels`)
```bash
gcloud org-policies describe vertexai.allowedModels \
  --project="${PROJECT_ID}" \
  --effective
```
Confirm only `publishers/google/models/gemini-4-hydrogen:predict`, `gemini-3.8-flash:predict`, and the listed lower models appear in `allowedValues`.

### 3.2 Verify Vertex AI Request-Response Logging
```bash
curl -sS -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://aiplatform.googleapis.com/v1beta1/projects/${PROJECT_ID}/locations/${VERTEX_LOCATION}/publishers/google/models/gemini-4-hydrogen:fetchPublisherModelConfig"
```

### 3.3 Test & Inspect Logs
1.  **Test allowed model:** Send a prompt in Antigravity (signed in with **Use business account** bound to `${PROJECT_ID}`) using `gemini-3.8-flash` or `gemini-4-hydrogen`.
2.  **Test disallowed model:** Attempt to call a non-allowlisted model (e.g., `gemini-4-argon` or a 3P Claude model); it should fail with an Organization Policy denial (`constraints/vertexai.allowedModels`).
3.  **Check BigQuery prompt/response logs:** Google Cloud Console → **BigQuery** → `${PROJECT_ID}.antigravity_logs.gemini_req_resp_logs`.

### 3.4 Query sample
1.  [Token usage per user daily](https://github.com/adithaha/gcp-agy-governance/blob/main/sql/token-usage-user.sql)

