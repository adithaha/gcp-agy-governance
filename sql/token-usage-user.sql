SELECT
  DATE(logging_time) AS log_date,
  JSON_VALUE(metadata, '$.principal_email') AS user_email,
  model,
  COUNT(*) AS total_requests,

  SUM(SAFE_CAST(
    JSON_VALUE(full_response, '$.usageMetadata.promptTokenCount')
    AS INT64
  )) AS input_tokens,

  SUM(SAFE_CAST(
    JSON_VALUE(full_response, '$.usageMetadata.candidatesTokenCount')
    AS INT64
  )) AS output_tokens,
  SUM(SAFE_CAST(
    JSON_VALUE(full_response, '$.usageMetadata.totalTokenCount')
    AS INT64
  )) AS total_tokens,
  SUM(SAFE_CAST(
    JSON_VALUE(full_response, '$.usageMetadata.cachedContentTokenCount')
    AS INT64
  )) AS cached_tokens

FROM
  `[PROJECT_ID]`.antigravity_logs.gemini_req_resp_logs

GROUP BY
  log_date,
  user_email,
  model

ORDER BY
  log_date DESC,
  total_tokens DESC;
