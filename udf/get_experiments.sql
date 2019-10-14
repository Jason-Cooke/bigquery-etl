CREATE TEMP FUNCTION
  udf_get_experiments(experiments ANY TYPE) AS ((
    SELECT
    AS STRUCT
      ARRAY_AGG(
        STRUCT(
          key,
          value.branch AS value
        )
      ) as key_value
    FROM
      UNNEST(experiments)
  ));
