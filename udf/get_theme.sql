CREATE TEMP FUNCTION
  udf_get_theme(theme STRUCT<app_disabled BOOL, blocklisted BOOL, description STRING, has_binary_components BOOL, id STRING, install_day INT64, name STRING, scope INT64, update_day INT64, user_disabled BOOL, version STRING>) AS (STRUCT(
    theme.app_disabled as app_disabled,
    theme.blocklisted as blocklisted,
    theme.description as description,
    theme.has_binary_components as has_binary_components,
    IFNULL(theme.id, "MISSING") as id,
    theme.install_day as install_day,
    theme.name as name,
    theme.scope as scope,
    theme.update_day as update_day,
    theme.user_disabled as user_disabled,
    theme.version as version
));

-- Tests

SELECT
  assert_equals(udf_get_theme(theme), theme),
  assert_equals(udf_get_theme(missing_theme).id, "MISSING")
FROM
(SELECT AS VALUE STRUCT(STRUCT(false AS app_disabled, false AS blocklisted, "desc" AS description, true AS has_binary_components, "foo" AS id, 7490 as install_day, "example theme" AS name, 0 as scope, 7551 as update_day, false AS user_disabled, "1.0.1" AS version) as theme,
STRUCT(false AS app_disabled, false AS blocklisted, "desc" AS description, true AS has_binary_components, NULL AS id, 7490 as install_day, "example theme" AS name, 0 as scope, 7551 as update_day, false AS user_disabled, "1.0.1" AS version) as missing_theme))
