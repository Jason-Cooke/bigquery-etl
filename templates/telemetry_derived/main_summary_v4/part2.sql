SELECT
  document_id,
  udf_js_histogram_row(payload, additional_properties).*,
  udf_addon_scalars_row(payload.processes, additional_properties).*
FROM
  `moz-fx-data-shared-prod.telemetry_stable.main_v4`
WHERE
  DATE(submission_timestamp) = @submission_date
  AND normalized_app_name = "Firefox"
  AND document_id IS NOT NULL
