/*

Returns an array of key/value structs from a string representing a JSON map.

Used by udf_scalar_row

*/

CREATE TEMP FUNCTION
  udf_json_extract_bool_map (input STRING) AS (ARRAY(
    SELECT
      STRUCT(CAST(SPLIT(entry, ':')[OFFSET(0)] AS STRING) AS key,
             CAST(SPLIT(entry, ':')[OFFSET(1)] AS BOOL) AS value)
    FROM
      UNNEST(SPLIT(REPLACE(TRIM(input, '{}'), '"', ''), ',')) AS entry
    WHERE
      LENGTH(entry) > 0 ));

-- Tests

SELECT
  assert_array_equals([STRUCT("a" AS key, true AS value),
                       STRUCT("blee" AS key, false AS value),
                       STRUCT("c" AS key, true AS value)],
                      udf_json_extract_bool_map('{"a":true,"blee":false,"c":true}')),
  assert_equals(0, ARRAY_LENGTH(udf_json_extract_bool_map('{}')));
