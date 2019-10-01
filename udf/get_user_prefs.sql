CREATE TEMP FUNCTION udf_get_user_prefs(user_prefs STRING)
RETURNS STRUCT<user_pref_browser_launcherprocess_enabled BOOLEAN,
  user_pref_browser_search_widget_innavbar BOOLEAN,
  user_pref_browser_search_region STRING,
  user_pref_extensions_allow_non_mpc_extensions BOOLEAN,
  user_pref_extensions_legacy_enabled BOOLEAN,
  user_pref_gfx_webrender_all_qualified BOOLEAN,
  user_pref_marionette_enabled BOOLEAN,
  user_pref_privacy_fuzzyfox_enabled BOOLEAN,
  user_pref_dom_ipc_plugins_sandbox_level_flash INT64,
  user_pref_dom_ipc_processcount INT64,
  user_pref_general_config_filename STRING,
  user_pref_security_enterprise_roots_auto_enabled BOOLEAN,
  user_pref_security_enterprise_roots_enabled BOOLEAN,
  user_pref_security_pki_mitm_detected BOOLEAN,
  user_pref_network_trr_mode INT64> AS (STRUCT(
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.browser.launcherProcess.enabled') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.browser.search.widget.inNavBar') AS BOOL),
    JSON_EXTRACT_SCALAR(user_prefs, '$.browser.search.region'),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.extensions.allow-non-mpc-extensions') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.extensions.legacy.enabled') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.gfx.webrender.all.qualified') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.marionette.enabled') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.privacy.fuzzyfox.enabled') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.dom.ipc.plugins.sandbox-level.flash') AS INT64),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.dom.ipc.processCount') AS INT64),
    JSON_EXTRACT_SCALAR(user_prefs, '$.general.config.filename'),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.security.enterprise_roots.auto-enabled') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.security.enterprise_roots.enabled') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.security.pki.mitm_detected') AS BOOL),
    CAST(JSON_EXTRACT_SCALAR(user_prefs, '$.network.trr.mode') AS INT64)
));


-- Tests

SELECT
  assert_equals(udf_get_user_prefs('{"browser": {"launcherProcess": {"enabled": true}, "search": {"widget":{"inNavBar":false}, "region": "DE"}}, "extensions": {"allow-non-mpc-extensions": true, "legacy": {"enabled": false}}, "gfx": {"webrender": {"all": {"qualified": false}}}, "marionette": {"enabled": true}, "privacy": {"fuzzyfox": {"enabled": true}}, "dom": {"ipc": {"plugins": {"sandbox-level": {"flash": 17}}, "processCount": 8}}, "general": {"config": {"filename": "myconfig.json"}}, "security": {"enterprise_roots": {"auto-enabled": false, "enabled": true}, "pki": {"mitm_detected": true}}, "network": {"trr": {"mode": 99}}}'),

    STRUCT(true AS user_pref_browser_launcherprocess_enabled, false AS user_pref_browser_search_widget_innavbar, "DE" AS user_pref_browser_search_region, true AS user_pref_extensions_allow_non_mpc_extensions, false AS user_pref_extensions_legacy_enabled, false AS user_pref_gfx_webrender_all_qualified, true AS user_pref_marionette_enabled, true AS user_pref_privacy_fuzzyfox_enabled, 17 AS user_pref_dom_ipc_plugins_sandbox_level_flash, 8 AS user_pref_dom_ipc_processcount, "myconfig.json" AS user_pref_general_config_filename, false AS user_pref_security_enterprise_roots_auto_enabled, true AS user_pref_security_enterprise_roots_enabled, true AS user_pref_security_pki_mitm_detected, 99 AS user_pref_network_trr_mode))
