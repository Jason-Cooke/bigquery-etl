CREATE TEMP FUNCTION
  udf_js_get_active_addons(active_addons ARRAY<STRUCT<key STRING,
    value STRUCT<app_disabled BOOL,
    blocklisted BOOL,
    description STRING,
    has_binary_components BOOL,
    install_day INT64,
    is_system BOOL,
    name STRING,
    scope INT64,
    signed_state INT64,
    type STRING,
    update_day INT64>>>,
    active_addons_json STRING)
  RETURNS ARRAY<STRUCT<addon_id STRING,
  blocklisted BOOL,
  name STRING,
  user_disabled BOOL,
  app_disabled BOOL,
  version STRING,
  scope INT64,
  type STRING,
  foreign_install BOOL,
  has_binary_components BOOL,
  install_day INT64,
  update_day INT64,
  is_system BOOL,
  is_web_extension BOOL,
  multiprocess_compatible BOOL>>
  LANGUAGE js AS """
var additional_properties = JSON.parse(active_addons_json);
var result = [];
active_addons.forEach((item) => {
  var addon_json = additional_properties[item.key];
  if (addon_json === undefined) {
    addon_json = {};
  }
  var value = item.value;
  if (value === undefined) {
    value = {};
  }
  result.push({
    "addon_id": item.key,
    "blocklisted": value.blocklisted,
    "name": value.name,
    "user_disabled": addon_json.userDisabled,
    "app_disabled": value.app_disabled,
    "version": addon_json.version,
    "scope": value.scope,
    "type": value.type,
    "foreign_install": addon_json.foreignInstall,
    "has_binary_components": value.has_binary_components,
    "install_day": value.install_day,
    "update_day": value.update_day,
    "is_system": value.is_system,
    "is_web_extension": addon_json.isWebExtension,
    "multiprocess_compatible": addon_json.multiprocessCompatible,
  });
});
return result;
""";

-- Tests

WITH result AS (SELECT AS VALUE
  udf_js_get_active_addons([("addon_id", (true, true, "", true, 2, true, "name", 1, 0, "type", 3))],
    '{"addon_id":{"multiprocessCompatible":true,"isWebExtension":true,"version":"version","userDisabled":true,"foreignInstall":true}}'))
SELECT
  assert_equals(1, ARRAY_LENGTH(result)),
  assert_equals(("addon_id", true, "name", true, true, "version", 1, "type", true, true, 2, 3, true, true, true), result[OFFSET(0)])
FROM
  result
