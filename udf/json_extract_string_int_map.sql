/*

Returns an array of key/value structs from a string representing a JSON map.

Used by udf_scalar_row.

*/

CREATE TEMP FUNCTION
  udf_json_extract_string_int_map (input STRING) AS (ARRAY(
    SELECT
      STRUCT(CAST(SPLIT(entry, ':')[OFFSET(0)] AS STRING) AS key,
             CAST(SPLIT(entry, ':')[OFFSET(1)] AS INT64) AS value)
    FROM
      UNNEST(SPLIT(REPLACE(TRIM(input, '{}'), '"', ''), ',')) AS entry
    WHERE
      LENGTH(entry) > 0 ));

-- Tests

SELECT
  assert_array_equals([STRUCT("0" AS key, 12434 AS value),
                       STRUCT("1" AS key, 297 AS value),
                       STRUCT("thirteen" AS key, 8 AS value)],
                      udf_json_extract_string_int_map('{"0":12434,"1":297,"thirteen":8}')),
  assert_equals(0, ARRAY_LENGTH(udf_json_extract_string_int_map('{}')));
