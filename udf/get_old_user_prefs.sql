CREATE TEMP FUNCTION
  udf_get_old_user_prefs(user_prefs_json STRING) AS (STRUCT(
      SAFE_CAST(JSON_EXTRACT_SCALAR(user_prefs_json, "$.dom.ipc.process_count") AS INT64) AS dom_ipc_process_count,
      SAFE_CAST(JSON_EXTRACT_SCALAR(user_prefs_json, "$.extensions.allow-non_mpc-extensions") AS BOOL) AS extensions_allow_non_mpc_extensions
));

-- Tests

WITH result AS (SELECT AS VALUE
  udf_get_old_user_prefs('{"dom":{"ipc":{"process_count":17}},"extensions":{"allow-non_mpc-extensions": true}}'))
SELECT
  assert_equals(result.dom_ipc_process_count, 17),
  assert_equals(result.extensions_allow_non_mpc_extensions, true)
FROM
  result
