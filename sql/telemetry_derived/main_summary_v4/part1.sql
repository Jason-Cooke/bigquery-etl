CREATE TEMP FUNCTION
  udf_boolean_histogram_to_boolean(histogram STRING) AS (
    COALESCE(SAFE_CAST(JSON_EXTRACT_SCALAR(histogram,
          "$.values.1") AS INT64) > 0,
      NOT SAFE_CAST( JSON_EXTRACT_SCALAR(histogram,
          "$.values.0") AS INT64) > 0));
CREATE TEMP FUNCTION
  udf_json_extract_int_map (input STRING) AS (ARRAY(
    SELECT
      STRUCT(CAST(SPLIT(entry, ':')[OFFSET(0)] AS INT64) AS key,
             CAST(SPLIT(entry, ':')[OFFSET(1)] AS INT64) AS value)
    FROM
      UNNEST(SPLIT(REPLACE(TRIM(input, '{}'), '"', ''), ',')) AS entry
    WHERE
      LENGTH(entry) > 0 ));
CREATE TEMP FUNCTION
  udf_json_extract_histogram (input STRING) AS (STRUCT(
    CAST(JSON_EXTRACT_SCALAR(input, '$.bucket_count') AS INT64) AS bucket_count,
    CAST(JSON_EXTRACT_SCALAR(input, '$.histogram_type') AS INT64) AS histogram_type,
    CAST(JSON_EXTRACT_SCALAR(input, '$.sum') AS INT64) AS `sum`,
    ARRAY(
      SELECT
        CAST(bound AS INT64)
      FROM
        UNNEST(SPLIT(TRIM(JSON_EXTRACT(input, '$.range'), '[]'), ',')) AS bound) AS `range`,
    udf_json_extract_int_map(JSON_EXTRACT(input, '$.values')) AS `values` ));
CREATE TEMP FUNCTION
  udf_enum_histogram_to_count(histogram STRING) AS ((
    SELECT
      MAX(value)
    FROM
      UNNEST(udf_json_extract_histogram(histogram).values)
    WHERE
      value > 0));
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
CREATE TEMP FUNCTION udf_get_key(map ANY TYPE, k ANY TYPE) AS (
 (
   SELECT key_value.value
   FROM UNNEST(map) AS key_value
   WHERE key_value.key = k
   LIMIT 1
 )
);
CREATE TEMP FUNCTION
  udf_get_old_user_prefs(user_prefs_json STRING) AS (STRUCT(
      SAFE_CAST(JSON_EXTRACT_SCALAR(user_prefs_json, "$.dom.ipc.process_count") AS INT64) AS dom_ipc_process_count,
      SAFE_CAST(JSON_EXTRACT_SCALAR(user_prefs_json, "$.extensions.allow-non_mpc-extensions") AS BOOL) AS extensions_allow_non_mpc_extensions
));
CREATE TEMP FUNCTION
  udf_get_plugins_notification_user_action(plugins_notification_user_action STRING) AS (
    ARRAY(
    SELECT
      AS STRUCT
      ANY_VALUE(IF(key = 0, value, NULL)) AS allow_now,
      ANY_VALUE(IF(key = 1, value, NULL)) AS allow_always,
      ANY_VALUE(IF(key = 2, value, NULL)) AS block
    FROM
      UNNEST(udf_json_extract_histogram(plugins_notification_user_action).values)));
CREATE TEMP FUNCTION
  udf_get_popup_notification_stats(popup_notification_stats ARRAY<STRUCT<key STRING, value STRING>>) AS (
    ARRAY(
    SELECT
      AS STRUCT
      _1.key,
      STRUCT(
        ANY_VALUE(IF(_0.key = 0,  _0.value, NULL)) AS offered,
        ANY_VALUE(IF(_0.key = 1,  _0.value, NULL)) AS action_1,
        ANY_VALUE(IF(_0.key = 2,  _0.value, NULL)) AS action_2,
        ANY_VALUE(IF(_0.key = 3,  _0.value, NULL)) AS action_3,
        ANY_VALUE(IF(_0.key = 4,  _0.value, NULL)) AS action_last,
        ANY_VALUE(IF(_0.key = 5,  _0.value, NULL)) AS dismissal_click_elsewhere,
        ANY_VALUE(IF(_0.key = 6,  _0.value, NULL)) AS dismissal_leave_page,
        ANY_VALUE(IF(_0.key = 7,  _0.value, NULL)) AS dismissal_close_button,
        ANY_VALUE(IF(_0.key = 8,  _0.value, NULL)) AS dismissal_not_now,
        ANY_VALUE(IF(_0.key = 10, _0.value, NULL)) AS open_submenu,
        ANY_VALUE(IF(_0.key = 11, _0.value, NULL)) AS learn_more,
        ANY_VALUE(IF(_0.key = 20, _0.value, NULL)) AS reopen_offered,
        ANY_VALUE(IF(_0.key = 21, _0.value, NULL)) AS reopen_action_1,
        ANY_VALUE(IF(_0.key = 22, _0.value, NULL)) AS reopen_action_2,
        ANY_VALUE(IF(_0.key = 23, _0.value, NULL)) AS reopen_action_3,
        ANY_VALUE(IF(_0.key = 24, _0.value, NULL)) AS reopen_action_last,
        ANY_VALUE(IF(_0.key = 25, _0.value, NULL)) AS reopen_dismissal_click_elsewhere,
        ANY_VALUE(IF(_0.key = 26, _0.value, NULL)) AS reopen_dismissal_leave_page,
        ANY_VALUE(IF(_0.key = 27, _0.value, NULL)) AS reopen_dismissal_close_button,
        ANY_VALUE(IF(_0.key = 28, _0.value, NULL)) AS reopen_dismissal_not_now,
        ANY_VALUE(IF(_0.key = 30, _0.value, NULL)) AS reopen_open_submenu,
        ANY_VALUE(IF(_0.key = 31, _0.value, NULL)) AS reopen_learn_more) AS value
    FROM
      UNNEST(popup_notification_stats) AS _1,
      UNNEST(udf_json_extract_histogram(_1.value).values) AS _0
    GROUP BY
      _1.key));
CREATE TEMP FUNCTION
  udf_get_search_counts(search_counts ARRAY<STRUCT<key STRING,
    value STRING>>) AS (
    ARRAY(
    SELECT
      AS STRUCT
      SUBSTR(key, 0, pos - 1) AS engine,
      SUBSTR(key, pos + 1) AS source,
      udf_json_extract_histogram(value).sum AS `count`
    FROM
      UNNEST(search_counts),
      UNNEST([REPLACE(key, "in-content.", "in-content:")]) AS key,
      UNNEST([STRPOS(key, ".")]) AS pos));
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
CREATE TEMP FUNCTION
udf_histogram_to_threshold_count(histogram STRING, threshold INT64) AS ((
    SELECT
    IFNULL(SUM(value), 0)
    FROM
      UNNEST(udf_json_extract_histogram(histogram).values)
    WHERE
      key >= threshold));
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
CREATE TEMP FUNCTION
  udf_js_get_disabled_addons(active_addons ARRAY<STRUCT<key STRING,
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
    addon_details_json STRING)
  RETURNS ARRAY<STRING>
  LANGUAGE js AS """
const addonDetails = JSON.parse(addon_details_json);
const activeIds = active_addons.map(item => item.key);
let result = [];
if (addonDetails !== undefined) {
  result = addonDetails.filter(k => activeIds.includes(k));
}
return result;
""";
CREATE TEMP FUNCTION
  udf_js_get_events(events_jsons ARRAY<STRUCT<process STRING, events_json STRING>>)
  RETURNS ARRAY<STRUCT<
    timestamp INT64,
    category STRING,
    method STRING,
    object STRING,
    string_value STRING,
    map_values ARRAY<STRUCT<key STRING, value STRING>>>>
  LANGUAGE js AS """
  return events_jsons.flatMap(({process, events_json}) =>
    JSON.parse(events_json).map((event) => {
      const pairs = Object.entries(event.map_values || {}).map(([key, value]) => ({key, value}));
      return {
        ...event,
        map_values: [{ key: "telemetry_process", value: process }, ...pairs]
      };
    }));
""";
CREATE TEMP FUNCTION
  udf_js_get_quantum_ready(e10s_enabled BOOL, active_addons ARRAY<STRUCT<key STRING,
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
  active_addons_json STRING,
  theme STRUCT<app_disabled BOOL, blocklisted BOOL, description STRING, has_binary_components BOOL, id STRING, install_day INT64, name STRING, scope INT64, update_day INT64, user_disabled BOOL, version STRING>)
    RETURNS BOOL
  LANGUAGE js AS """
    const activeAddonsExtras = JSON.parse(active_addons_json);
    return (e10s_enabled &&
            active_addons.every(a => a.value.is_system || (activeAddonsExtras[a.key] && activeAddonsExtras[a.key].isWebExtension)) &&
            ["{972ce4c6-7e08-4474-a285-3208198ce6fd}",
             "firefox-compact-light@mozilla.org",
             "firefox-compact-dark@mozilla.org"].includes(theme.id));
  """;
CREATE TEMP FUNCTION
  udf_max_flash_version(active_plugins ANY TYPE) AS ((
    SELECT
      AS STRUCT
      version,
      SAFE_CAST(parts[SAFE_OFFSET(0)] AS INT64) AS major,
      SAFE_CAST(parts[SAFE_OFFSET(1)] AS INT64) AS minor,
      SAFE_CAST(parts[SAFE_OFFSET(2)] AS INT64) AS patch,
      SAFE_CAST(parts[SAFE_OFFSET(3)] AS INT64) AS build
    FROM
      UNNEST(active_plugins),
      UNNEST([STRUCT(SPLIT(version, ".") AS parts)])
    WHERE
      name = "Shockwave Flash"
    ORDER BY
      major DESC,
      minor DESC,
      patch DESC,
      build DESC
    LIMIT
      1).version);
CREATE TEMP FUNCTION
  udf_json_extract_string_int_map (input STRING) AS (ARRAY(
    SELECT
      STRUCT(CAST(SPLIT(entry, ':')[OFFSET(0)] AS STRING) AS key,
             CAST(SPLIT(entry, ':')[OFFSET(1)] AS INT64) AS value)
    FROM
      UNNEST(SPLIT(REPLACE(TRIM(input, '{}'), '"', ''), ',')) AS entry
    WHERE
      LENGTH(entry) > 0 ));
CREATE TEMP FUNCTION
  udf_scalar_row(processes ANY TYPE, additional_properties STRING)
  returns STRUCT<scalar_parent_a11y_indicator_acted_on BOOL,
scalar_parent_a11y_instantiators STRING,
scalar_parent_aushelper_websense_reg_version STRING,
scalar_parent_blocklist_last_modified_rs_addons STRING,
scalar_parent_blocklist_last_modified_rs_plugins STRING,
scalar_parent_blocklist_last_modified_xml STRING,
scalar_parent_blocklist_use_xml BOOL,
scalar_parent_browser_engagement_active_ticks INT64,
scalar_parent_browser_engagement_max_concurrent_tab_count INT64,
scalar_parent_browser_engagement_max_concurrent_tab_pinned_count INT64,
scalar_parent_browser_engagement_max_concurrent_window_count INT64,
scalar_parent_browser_engagement_restored_pinned_tabs_count INT64,
scalar_parent_browser_engagement_tab_open_event_count INT64,
scalar_parent_browser_engagement_tab_pinned_event_count INT64,
scalar_parent_browser_engagement_total_uri_count INT64,
scalar_parent_browser_engagement_unfiltered_uri_count INT64,
scalar_parent_browser_engagement_unique_domains_count INT64,
scalar_parent_browser_engagement_window_open_event_count INT64,
scalar_parent_browser_errors_collected_count INT64,
scalar_parent_browser_errors_collected_with_stack_count INT64,
scalar_parent_browser_errors_reported_failure_count INT64,
scalar_parent_browser_errors_reported_success_count INT64,
scalar_parent_browser_errors_sample_rate STRING,
scalar_parent_browser_feeds_feed_subscribed INT64,
scalar_parent_browser_feeds_livebookmark_count INT64,
scalar_parent_browser_feeds_livebookmark_item_opened INT64,
scalar_parent_browser_feeds_livebookmark_opened INT64,
scalar_parent_browser_feeds_preview_loaded INT64,
scalar_parent_browser_session_restore_browser_startup_page INT64,
scalar_parent_browser_session_restore_browser_tabs_restorebutton INT64,
scalar_parent_browser_session_restore_number_of_tabs INT64,
scalar_parent_browser_session_restore_number_of_win INT64,
scalar_parent_browser_session_restore_tabbar_restore_available BOOL,
scalar_parent_browser_session_restore_tabbar_restore_clicked BOOL,
scalar_parent_browser_session_restore_worker_restart_count INT64,
scalar_parent_browser_timings_last_shutdown INT64,
scalar_parent_browser_usage_graphite INT64,
scalar_parent_browser_usage_plugin_instantiated INT64,
scalar_parent_contentblocking_category INT64,
scalar_parent_contentblocking_cryptomining_blocking_enabled BOOL,
scalar_parent_contentblocking_enabled BOOL,
scalar_parent_contentblocking_exceptions INT64,
scalar_parent_contentblocking_fastblock_enabled BOOL,
scalar_parent_contentblocking_fingerprinting_blocking_enabled BOOL,
scalar_parent_corroborate_omnijar_corrupted BOOL,
scalar_parent_corroborate_system_addons_corrupted BOOL,
scalar_parent_devtools_aboutdevtools_installed INT64,
scalar_parent_devtools_aboutdevtools_noinstall_exits INT64,
scalar_parent_devtools_aboutdevtools_opened INT64,
scalar_parent_devtools_accessibility_accessible_context_menu_opened INT64,
scalar_parent_devtools_accessibility_node_inspected_count INT64,
scalar_parent_devtools_accessibility_opened_count INT64,
scalar_parent_devtools_accessibility_picker_used_count INT64,
scalar_parent_devtools_accessibility_service_enabled_count INT64,
scalar_parent_devtools_application_opened_count INT64,
scalar_parent_devtools_changesview_contextmenu INT64,
scalar_parent_devtools_changesview_contextmenu_copy INT64,
scalar_parent_devtools_changesview_contextmenu_copy_declaration INT64,
scalar_parent_devtools_changesview_contextmenu_copy_rule INT64,
scalar_parent_devtools_changesview_copy INT64,
scalar_parent_devtools_changesview_copy_all_changes INT64,
scalar_parent_devtools_changesview_copy_rule INT64,
scalar_parent_devtools_changesview_opened_count INT64,
scalar_parent_devtools_copy_full_css_selector_opened INT64,
scalar_parent_devtools_copy_unique_css_selector_opened INT64,
scalar_parent_devtools_copy_xpath_opened INT64,
scalar_parent_devtools_grid_gridinspector_opened INT64,
scalar_parent_devtools_grid_show_grid_areas_overlay_checked INT64,
scalar_parent_devtools_grid_show_grid_line_numbers_checked INT64,
scalar_parent_devtools_grid_show_infinite_lines_checked INT64,
scalar_parent_devtools_inspector_element_picker_used INT64,
scalar_parent_devtools_inspector_node_selection_count INT64,
scalar_parent_devtools_layout_flexboxhighlighter_opened INT64,
scalar_parent_devtools_markup_flexboxhighlighter_opened INT64,
scalar_parent_devtools_markup_gridinspector_opened INT64,
scalar_parent_devtools_onboarding_is_devtools_user BOOL,
scalar_parent_devtools_responsive_toolbox_opened_first INT64,
scalar_parent_devtools_rules_flexboxhighlighter_opened INT64,
scalar_parent_devtools_rules_gridinspector_opened INT64,
scalar_parent_devtools_shadowdom_reveal_link_clicked BOOL,
scalar_parent_devtools_shadowdom_shadow_root_displayed BOOL,
scalar_parent_devtools_shadowdom_shadow_root_expanded BOOL,
scalar_parent_devtools_toolbar_eyedropper_opened INT64,
scalar_parent_devtools_webreplay_load_recording INT64,
scalar_parent_devtools_webreplay_new_recording INT64,
scalar_parent_devtools_webreplay_reload_recording INT64,
scalar_parent_devtools_webreplay_save_recording INT64,
scalar_parent_devtools_webreplay_stop_recording INT64,
scalar_parent_dom_contentprocess_build_id_mismatch INT64,
scalar_parent_dom_contentprocess_os_priority_change_considered INT64,
scalar_parent_dom_contentprocess_os_priority_lowered INT64,
scalar_parent_dom_contentprocess_os_priority_raised INT64,
scalar_parent_dom_contentprocess_troubled_due_to_memory INT64,
scalar_parent_dom_parentprocess_private_window_used BOOL,
scalar_parent_encoding_override_used BOOL,
scalar_parent_first_startup_status_code INT64,
scalar_parent_formautofill_addresses_fill_type_autofill INT64,
scalar_parent_formautofill_addresses_fill_type_autofill_update INT64,
scalar_parent_formautofill_addresses_fill_type_manual INT64,
scalar_parent_formautofill_availability BOOL,
scalar_parent_formautofill_credit_cards_fill_type_autofill INT64,
scalar_parent_formautofill_credit_cards_fill_type_autofill_modified INT64,
scalar_parent_formautofill_credit_cards_fill_type_manual INT64,
scalar_parent_gfx_hdr_windows_display_colorspace_bitfield INT64,
scalar_parent_idb_failure_fileinfo_error INT64,
scalar_parent_idb_type_persistent_count INT64,
scalar_parent_idb_type_temporary_count INT64,
scalar_parent_identity_fxaccounts_missed_commands_fetched INT64,
scalar_parent_images_webp_content_observed BOOL,
scalar_parent_images_webp_probe_observed BOOL,
scalar_parent_media_allowed_autoplay_no_audio_track_count INT64,
scalar_parent_media_autoplay_default_blocked BOOL,
scalar_parent_media_autoplay_would_be_allowed_count INT64,
scalar_parent_media_autoplay_would_not_be_allowed_count INT64,
scalar_parent_media_blocked_no_metadata INT64,
scalar_parent_media_blocked_no_metadata_endup_no_audio_track INT64,
scalar_parent_media_page_count INT64,
scalar_parent_media_page_had_media_count INT64,
scalar_parent_media_page_had_play_revoked_count INT64,
scalar_parent_mediarecorder_recording_count INT64,
scalar_parent_navigator_storage_estimate_count INT64,
scalar_parent_navigator_storage_persist_count INT64,
scalar_parent_network_tcp_overlapped_io_canceled_before_finished INT64,
scalar_parent_network_tcp_overlapped_result_delayed INT64,
scalar_parent_networking_data_transferred_captive_portal INT64,
scalar_parent_networking_http_connections_captive_portal INT64,
scalar_parent_networking_http_transactions_captive_portal INT64,
scalar_parent_os_environment_is_admin_without_uac BOOL,
scalar_parent_pdf_viewer_fallback_shown INT64,
scalar_parent_pdf_viewer_print INT64,
scalar_parent_pdf_viewer_used INT64,
scalar_parent_preferences_created_new_user_prefs_file BOOL,
scalar_parent_preferences_prefs_file_was_invalid BOOL,
scalar_parent_preferences_prevent_accessibility_services BOOL,
scalar_parent_preferences_read_user_js BOOL,
scalar_parent_screenshots_copy INT64,
scalar_parent_screenshots_download INT64,
scalar_parent_screenshots_upload INT64,
scalar_parent_script_preloader_mainthread_recompile INT64,
scalar_parent_security_intermediate_preloading_num_pending INT64,
scalar_parent_security_intermediate_preloading_num_preloaded INT64,
scalar_parent_services_sync_fxa_verification_method STRING,
scalar_parent_startup_is_cold BOOL,
scalar_parent_startup_profile_selection_reason STRING,
scalar_parent_storage_sync_api_usage_extensions_using INT64,
scalar_parent_sw_alternative_body_used_count INT64,
scalar_parent_sw_cors_res_for_so_req_count INT64,
scalar_parent_sw_synthesized_res_count INT64,
scalar_parent_telemetry_about_telemetry_pageload INT64,
scalar_parent_telemetry_data_upload_optin BOOL,
scalar_parent_telemetry_ecosystem_new_send_time STRING,
scalar_parent_telemetry_ecosystem_old_send_time STRING,
scalar_parent_telemetry_os_shutting_down BOOL,
scalar_parent_telemetry_pending_operations_highwatermark_reached INT64,
scalar_parent_telemetry_persistence_timer_hit_count INT64,
scalar_parent_telemetry_process_creation_timestamp_inconsistent INT64,
scalar_parent_telemetry_profile_directory_scan_date INT64,
scalar_parent_telemetry_profile_directory_scans INT64,
scalar_parent_timestamps_about_home_topsites_first_paint INT64,
scalar_parent_timestamps_first_paint INT64,
scalar_parent_update_session_downloads_bits_complete_bytes INT64,
scalar_parent_update_session_downloads_bits_complete_seconds INT64,
scalar_parent_update_session_downloads_bits_partial_bytes INT64,
scalar_parent_update_session_downloads_bits_partial_seconds INT64,
scalar_parent_update_session_downloads_internal_complete_bytes INT64,
scalar_parent_update_session_downloads_internal_complete_seconds INT64,
scalar_parent_update_session_downloads_internal_partial_bytes INT64,
scalar_parent_update_session_downloads_internal_partial_seconds INT64,
scalar_parent_update_session_from_app_version STRING,
scalar_parent_update_session_intervals_apply_complete INT64,
scalar_parent_update_session_intervals_apply_partial INT64,
scalar_parent_update_session_intervals_check INT64,
scalar_parent_update_session_intervals_download_bits_complete INT64,
scalar_parent_update_session_intervals_download_bits_partial INT64,
scalar_parent_update_session_intervals_download_internal_complete INT64,
scalar_parent_update_session_intervals_download_internal_partial INT64,
scalar_parent_update_session_intervals_stage_complete INT64,
scalar_parent_update_session_intervals_stage_partial INT64,
scalar_parent_update_session_mar_complete_size_bytes INT64,
scalar_parent_update_session_mar_partial_size_bytes INT64,
scalar_parent_update_startup_downloads_bits_complete_bytes INT64,
scalar_parent_update_startup_downloads_bits_complete_seconds INT64,
scalar_parent_update_startup_downloads_bits_partial_bytes INT64,
scalar_parent_update_startup_downloads_bits_partial_seconds INT64,
scalar_parent_update_startup_downloads_internal_complete_bytes INT64,
scalar_parent_update_startup_downloads_internal_complete_seconds INT64,
scalar_parent_update_startup_downloads_internal_partial_bytes INT64,
scalar_parent_update_startup_downloads_internal_partial_seconds INT64,
scalar_parent_update_startup_from_app_version STRING,
scalar_parent_update_startup_intervals_apply_complete INT64,
scalar_parent_update_startup_intervals_apply_partial INT64,
scalar_parent_update_startup_intervals_check INT64,
scalar_parent_update_startup_intervals_download_bits_complete INT64,
scalar_parent_update_startup_intervals_download_bits_partial INT64,
scalar_parent_update_startup_intervals_download_internal_complete INT64,
scalar_parent_update_startup_intervals_download_internal_partial INT64,
scalar_parent_update_startup_intervals_stage_complete INT64,
scalar_parent_update_startup_intervals_stage_partial INT64,
scalar_parent_update_startup_mar_complete_size_bytes INT64,
scalar_parent_update_startup_mar_partial_size_bytes INT64,
scalar_parent_webrtc_nicer_stun_retransmits INT64,
scalar_parent_webrtc_nicer_turn_401s INT64,
scalar_parent_webrtc_nicer_turn_403s INT64,
scalar_parent_webrtc_nicer_turn_438s INT64,
scalar_parent_webrtc_peerconnection_connected INT64,
scalar_parent_webrtc_peerconnection_datachannel_created INT64,
scalar_parent_webrtc_peerconnection_datachannel_max_life_used INT64,
scalar_parent_webrtc_peerconnection_datachannel_max_retx_and_life_used INT64,
scalar_parent_webrtc_peerconnection_datachannel_max_retx_used INT64,
scalar_parent_webrtc_peerconnection_legacy_callback_stats_used INT64,
scalar_parent_webrtc_peerconnection_promise_and_callback_stats_used INT64,
scalar_parent_webrtc_peerconnection_promise_stats_used INT64,
scalar_content_browser_feeds_preview_loaded INT64,
scalar_content_browser_usage_graphite INT64,
scalar_content_browser_usage_plugin_instantiated INT64,
scalar_content_encoding_override_used BOOL,
scalar_content_gfx_omtp_paint_wait_ratio INT64,
scalar_content_idb_type_persistent_count INT64,
scalar_content_idb_type_temporary_count INT64,
scalar_content_images_webp_content_observed BOOL,
scalar_content_images_webp_probe_observed BOOL,
scalar_content_mathml_doc_count INT64,
scalar_content_media_allowed_autoplay_no_audio_track_count INT64,
scalar_content_media_autoplay_default_blocked BOOL,
scalar_content_media_autoplay_would_be_allowed_count INT64,
scalar_content_media_autoplay_would_not_be_allowed_count INT64,
scalar_content_media_blocked_no_metadata INT64,
scalar_content_media_blocked_no_metadata_endup_no_audio_track INT64,
scalar_content_media_page_count INT64,
scalar_content_media_page_had_media_count INT64,
scalar_content_media_page_had_play_revoked_count INT64,
scalar_content_mediarecorder_recording_count INT64,
scalar_content_memoryreporter_max_ghost_windows INT64,
scalar_content_navigator_storage_estimate_count INT64,
scalar_content_navigator_storage_persist_count INT64,
scalar_content_pdf_viewer_fallback_shown INT64,
scalar_content_pdf_viewer_print INT64,
scalar_content_pdf_viewer_used INT64,
scalar_content_script_preloader_mainthread_recompile INT64,
scalar_content_sw_alternative_body_used_count INT64,
scalar_content_sw_cors_res_for_so_req_count INT64,
scalar_content_sw_synthesized_res_count INT64,
scalar_content_telemetry_discarded_accumulations INT64,
scalar_content_telemetry_discarded_child_events INT64,
scalar_content_telemetry_discarded_keyed_accumulations INT64,
scalar_content_telemetry_discarded_keyed_scalar_actions INT64,
scalar_content_telemetry_discarded_scalar_actions INT64,
scalar_content_telemetry_process_creation_timestamp_inconsistent INT64,
scalar_content_telemetry_profile_directory_scans INT64,
scalar_content_webrtc_nicer_stun_retransmits INT64,
scalar_content_webrtc_nicer_turn_401s INT64,
scalar_content_webrtc_nicer_turn_403s INT64,
scalar_content_webrtc_nicer_turn_438s INT64,
scalar_content_webrtc_peerconnection_connected INT64,
scalar_content_webrtc_peerconnection_datachannel_created INT64,
scalar_content_webrtc_peerconnection_datachannel_max_life_used INT64,
scalar_content_webrtc_peerconnection_datachannel_max_retx_and_life_used INT64,
scalar_content_webrtc_peerconnection_datachannel_max_retx_used INT64,
scalar_content_webrtc_peerconnection_legacy_callback_stats_used INT64,
scalar_content_webrtc_peerconnection_promise_and_callback_stats_used INT64,
scalar_content_webrtc_peerconnection_promise_stats_used INT64,
scalar_parent_a11y_theme ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_parent_browser_engagement_navigation_about_home ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_engagement_navigation_about_newtab ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_engagement_navigation_contextmenu ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_engagement_navigation_searchbar ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_engagement_navigation_urlbar ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_engagement_navigation_webextension ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_errors_collected_count_by_filename ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_search_ad_clicks ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_browser_search_with_ads ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_accessibility_accessible_context_menu_item_activated ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_accessibility_audit_activated ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_accessibility_select_accessible_for_node ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_accessibility_simulation_activated ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_current_theme ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_inspector_three_pane_enabled ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_responsive_open_trigger ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_tool_registered ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_parent_devtools_toolbox_tabs_reordered ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_devtools_tooltip_shown ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_extensions_updates_rdf ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_gfx_advanced_layers_failure_id ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_images_webp_content_frequency ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_networking_data_transferred_kb ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_networking_data_transferred_v3_kb ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_normandy_recipe_freshness ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_pictureinpicture_closed_method ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_preferences_browser_home_page_change ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_preferences_browser_home_page_count ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_preferences_search_query ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_preferences_use_bookmark ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_preferences_use_current_page ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_qm_origin_directory_unexpected_filename ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_resistfingerprinting_content_window_size ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_sandbox_no_job ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_parent_security_client_cert ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_security_pkcs11_modules_loaded ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_parent_security_webauthn_used ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_services_sync_sync_login_state_transitions ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_parent_storage_sync_api_usage_items_stored ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_storage_sync_api_usage_storage_consumed ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_telemetry_accumulate_clamped_values ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_telemetry_accumulate_unknown_histogram_keys ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_telemetry_event_counts ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_telemetry_keyed_scalars_exceed_limit ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_update_binarytransparencyresult ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_update_bitshresult ARRAY<STRUCT<key STRING, value INT64>>,
scalar_parent_widget_ime_name_on_linux ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_parent_widget_ime_name_on_mac ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_parent_widget_ime_name_on_windows ARRAY<STRUCT<key STRING, value BOOL>>,
scalar_content_dom_event_confluence_load_count ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_dom_event_office_online_load_count ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_gfx_small_paint_phase_weight ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_images_webp_content_frequency ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_pictureinpicture_opened_method ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_telemetry_accumulate_unknown_histogram_keys ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_telemetry_event_counts ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_webrtc_sdp_parser_diff ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_webrtc_video_recv_codec_used ARRAY<STRUCT<key STRING, value INT64>>,
scalar_content_webrtc_video_send_codec_used ARRAY<STRUCT<key STRING, value INT64>>>
  AS (STRUCT(
      processes.parent.scalars.a11y_indicator_acted_on AS scalar_parent_a11y_indicator_acted_on,
processes.parent.scalars.a11y_instantiators AS scalar_parent_a11y_instantiators,
processes.parent.scalars.aushelper_websense_reg_version AS scalar_parent_aushelper_websense_reg_version,
processes.parent.scalars.blocklist_last_modified_rs_addons AS scalar_parent_blocklist_last_modified_rs_addons,
processes.parent.scalars.blocklist_last_modified_rs_plugins AS scalar_parent_blocklist_last_modified_rs_plugins,
processes.parent.scalars.blocklist_last_modified_xml AS scalar_parent_blocklist_last_modified_xml,
processes.parent.scalars.blocklist_use_xml AS scalar_parent_blocklist_use_xml,
processes.parent.scalars.browser_engagement_active_ticks AS scalar_parent_browser_engagement_active_ticks,
processes.parent.scalars.browser_engagement_max_concurrent_tab_count AS scalar_parent_browser_engagement_max_concurrent_tab_count,
processes.parent.scalars.browser_engagement_max_concurrent_tab_pinned_count AS scalar_parent_browser_engagement_max_concurrent_tab_pinned_count,
processes.parent.scalars.browser_engagement_max_concurrent_window_count AS scalar_parent_browser_engagement_max_concurrent_window_count,
processes.parent.scalars.browser_engagement_restored_pinned_tabs_count AS scalar_parent_browser_engagement_restored_pinned_tabs_count,
processes.parent.scalars.browser_engagement_tab_open_event_count AS scalar_parent_browser_engagement_tab_open_event_count,
processes.parent.scalars.browser_engagement_tab_pinned_event_count AS scalar_parent_browser_engagement_tab_pinned_event_count,
processes.parent.scalars.browser_engagement_total_uri_count AS scalar_parent_browser_engagement_total_uri_count,
processes.parent.scalars.browser_engagement_unfiltered_uri_count AS scalar_parent_browser_engagement_unfiltered_uri_count,
processes.parent.scalars.browser_engagement_unique_domains_count AS scalar_parent_browser_engagement_unique_domains_count,
processes.parent.scalars.browser_engagement_window_open_event_count AS scalar_parent_browser_engagement_window_open_event_count,
processes.parent.scalars.browser_errors_collected_count AS scalar_parent_browser_errors_collected_count,
processes.parent.scalars.browser_errors_collected_with_stack_count AS scalar_parent_browser_errors_collected_with_stack_count,
processes.parent.scalars.browser_errors_reported_failure_count AS scalar_parent_browser_errors_reported_failure_count,
processes.parent.scalars.browser_errors_reported_success_count AS scalar_parent_browser_errors_reported_success_count,
processes.parent.scalars.browser_errors_sample_rate AS scalar_parent_browser_errors_sample_rate,
processes.parent.scalars.browser_feeds_feed_subscribed AS scalar_parent_browser_feeds_feed_subscribed,
processes.parent.scalars.browser_feeds_livebookmark_count AS scalar_parent_browser_feeds_livebookmark_count,
processes.parent.scalars.browser_feeds_livebookmark_item_opened AS scalar_parent_browser_feeds_livebookmark_item_opened,
processes.parent.scalars.browser_feeds_livebookmark_opened AS scalar_parent_browser_feeds_livebookmark_opened,
processes.parent.scalars.browser_feeds_preview_loaded AS scalar_parent_browser_feeds_preview_loaded,
processes.parent.scalars.browser_session_restore_browser_startup_page AS scalar_parent_browser_session_restore_browser_startup_page,
processes.parent.scalars.browser_session_restore_browser_tabs_restorebutton AS scalar_parent_browser_session_restore_browser_tabs_restorebutton,
processes.parent.scalars.browser_session_restore_number_of_tabs AS scalar_parent_browser_session_restore_number_of_tabs,
processes.parent.scalars.browser_session_restore_number_of_win AS scalar_parent_browser_session_restore_number_of_win,
processes.parent.scalars.browser_session_restore_tabbar_restore_available AS scalar_parent_browser_session_restore_tabbar_restore_available,
processes.parent.scalars.browser_session_restore_tabbar_restore_clicked AS scalar_parent_browser_session_restore_tabbar_restore_clicked,
processes.parent.scalars.browser_session_restore_worker_restart_count AS scalar_parent_browser_session_restore_worker_restart_count,
processes.parent.scalars.browser_timings_last_shutdown AS scalar_parent_browser_timings_last_shutdown,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.parent.scalars.browser_usage_graphite') AS INT64) AS scalar_parent_browser_usage_graphite,
processes.parent.scalars.browser_usage_plugin_instantiated AS scalar_parent_browser_usage_plugin_instantiated,
processes.parent.scalars.contentblocking_category AS scalar_parent_contentblocking_category,
processes.parent.scalars.contentblocking_cryptomining_blocking_enabled AS scalar_parent_contentblocking_cryptomining_blocking_enabled,
processes.parent.scalars.contentblocking_enabled AS scalar_parent_contentblocking_enabled,
processes.parent.scalars.contentblocking_exceptions AS scalar_parent_contentblocking_exceptions,
processes.parent.scalars.contentblocking_fastblock_enabled AS scalar_parent_contentblocking_fastblock_enabled,
processes.parent.scalars.contentblocking_fingerprinting_blocking_enabled AS scalar_parent_contentblocking_fingerprinting_blocking_enabled,
processes.parent.scalars.corroborate_omnijar_corrupted AS scalar_parent_corroborate_omnijar_corrupted,
processes.parent.scalars.corroborate_system_addons_corrupted AS scalar_parent_corroborate_system_addons_corrupted,
processes.parent.scalars.devtools_aboutdevtools_installed AS scalar_parent_devtools_aboutdevtools_installed,
processes.parent.scalars.devtools_aboutdevtools_noinstall_exits AS scalar_parent_devtools_aboutdevtools_noinstall_exits,
processes.parent.scalars.devtools_aboutdevtools_opened AS scalar_parent_devtools_aboutdevtools_opened,
processes.parent.scalars.devtools_accessibility_accessible_context_menu_opened AS scalar_parent_devtools_accessibility_accessible_context_menu_opened,
processes.parent.scalars.devtools_accessibility_node_inspected_count AS scalar_parent_devtools_accessibility_node_inspected_count,
processes.parent.scalars.devtools_accessibility_opened_count AS scalar_parent_devtools_accessibility_opened_count,
processes.parent.scalars.devtools_accessibility_picker_used_count AS scalar_parent_devtools_accessibility_picker_used_count,
processes.parent.scalars.devtools_accessibility_service_enabled_count AS scalar_parent_devtools_accessibility_service_enabled_count,
processes.parent.scalars.devtools_application_opened_count AS scalar_parent_devtools_application_opened_count,
processes.parent.scalars.devtools_changesview_contextmenu AS scalar_parent_devtools_changesview_contextmenu,
processes.parent.scalars.devtools_changesview_contextmenu_copy AS scalar_parent_devtools_changesview_contextmenu_copy,
processes.parent.scalars.devtools_changesview_contextmenu_copy_declaration AS scalar_parent_devtools_changesview_contextmenu_copy_declaration,
processes.parent.scalars.devtools_changesview_contextmenu_copy_rule AS scalar_parent_devtools_changesview_contextmenu_copy_rule,
processes.parent.scalars.devtools_changesview_copy AS scalar_parent_devtools_changesview_copy,
processes.parent.scalars.devtools_changesview_copy_all_changes AS scalar_parent_devtools_changesview_copy_all_changes,
processes.parent.scalars.devtools_changesview_copy_rule AS scalar_parent_devtools_changesview_copy_rule,
processes.parent.scalars.devtools_changesview_opened_count AS scalar_parent_devtools_changesview_opened_count,
processes.parent.scalars.devtools_copy_full_css_selector_opened AS scalar_parent_devtools_copy_full_css_selector_opened,
processes.parent.scalars.devtools_copy_unique_css_selector_opened AS scalar_parent_devtools_copy_unique_css_selector_opened,
processes.parent.scalars.devtools_copy_xpath_opened AS scalar_parent_devtools_copy_xpath_opened,
processes.parent.scalars.devtools_grid_gridinspector_opened AS scalar_parent_devtools_grid_gridinspector_opened,
processes.parent.scalars.devtools_grid_show_grid_areas_overlay_checked AS scalar_parent_devtools_grid_show_grid_areas_overlay_checked,
processes.parent.scalars.devtools_grid_show_grid_line_numbers_checked AS scalar_parent_devtools_grid_show_grid_line_numbers_checked,
processes.parent.scalars.devtools_grid_show_infinite_lines_checked AS scalar_parent_devtools_grid_show_infinite_lines_checked,
processes.parent.scalars.devtools_inspector_element_picker_used AS scalar_parent_devtools_inspector_element_picker_used,
processes.parent.scalars.devtools_inspector_node_selection_count AS scalar_parent_devtools_inspector_node_selection_count,
processes.parent.scalars.devtools_layout_flexboxhighlighter_opened AS scalar_parent_devtools_layout_flexboxhighlighter_opened,
processes.parent.scalars.devtools_markup_flexboxhighlighter_opened AS scalar_parent_devtools_markup_flexboxhighlighter_opened,
processes.parent.scalars.devtools_markup_gridinspector_opened AS scalar_parent_devtools_markup_gridinspector_opened,
processes.parent.scalars.devtools_onboarding_is_devtools_user AS scalar_parent_devtools_onboarding_is_devtools_user,
processes.parent.scalars.devtools_responsive_toolbox_opened_first AS scalar_parent_devtools_responsive_toolbox_opened_first,
processes.parent.scalars.devtools_rules_flexboxhighlighter_opened AS scalar_parent_devtools_rules_flexboxhighlighter_opened,
processes.parent.scalars.devtools_rules_gridinspector_opened AS scalar_parent_devtools_rules_gridinspector_opened,
processes.parent.scalars.devtools_shadowdom_reveal_link_clicked AS scalar_parent_devtools_shadowdom_reveal_link_clicked,
processes.parent.scalars.devtools_shadowdom_shadow_root_displayed AS scalar_parent_devtools_shadowdom_shadow_root_displayed,
processes.parent.scalars.devtools_shadowdom_shadow_root_expanded AS scalar_parent_devtools_shadowdom_shadow_root_expanded,
processes.parent.scalars.devtools_toolbar_eyedropper_opened AS scalar_parent_devtools_toolbar_eyedropper_opened,
processes.parent.scalars.devtools_webreplay_load_recording AS scalar_parent_devtools_webreplay_load_recording,
processes.parent.scalars.devtools_webreplay_new_recording AS scalar_parent_devtools_webreplay_new_recording,
processes.parent.scalars.devtools_webreplay_reload_recording AS scalar_parent_devtools_webreplay_reload_recording,
processes.parent.scalars.devtools_webreplay_save_recording AS scalar_parent_devtools_webreplay_save_recording,
processes.parent.scalars.devtools_webreplay_stop_recording AS scalar_parent_devtools_webreplay_stop_recording,
processes.parent.scalars.dom_contentprocess_build_id_mismatch AS scalar_parent_dom_contentprocess_build_id_mismatch,
processes.parent.scalars.dom_contentprocess_os_priority_change_considered AS scalar_parent_dom_contentprocess_os_priority_change_considered,
processes.parent.scalars.dom_contentprocess_os_priority_lowered AS scalar_parent_dom_contentprocess_os_priority_lowered,
processes.parent.scalars.dom_contentprocess_os_priority_raised AS scalar_parent_dom_contentprocess_os_priority_raised,
processes.parent.scalars.dom_contentprocess_troubled_due_to_memory AS scalar_parent_dom_contentprocess_troubled_due_to_memory,
processes.parent.scalars.dom_parentprocess_private_window_used AS scalar_parent_dom_parentprocess_private_window_used,
processes.parent.scalars.encoding_override_used AS scalar_parent_encoding_override_used,
processes.parent.scalars.first_startup_status_code AS scalar_parent_first_startup_status_code,
processes.parent.scalars.formautofill_addresses_fill_type_autofill AS scalar_parent_formautofill_addresses_fill_type_autofill,
processes.parent.scalars.formautofill_addresses_fill_type_autofill_update AS scalar_parent_formautofill_addresses_fill_type_autofill_update,
processes.parent.scalars.formautofill_addresses_fill_type_manual AS scalar_parent_formautofill_addresses_fill_type_manual,
processes.parent.scalars.formautofill_availability AS scalar_parent_formautofill_availability,
processes.parent.scalars.formautofill_credit_cards_fill_type_autofill AS scalar_parent_formautofill_credit_cards_fill_type_autofill,
processes.parent.scalars.formautofill_credit_cards_fill_type_autofill_modified AS scalar_parent_formautofill_credit_cards_fill_type_autofill_modified,
processes.parent.scalars.formautofill_credit_cards_fill_type_manual AS scalar_parent_formautofill_credit_cards_fill_type_manual,
processes.parent.scalars.gfx_hdr_windows_display_colorspace_bitfield AS scalar_parent_gfx_hdr_windows_display_colorspace_bitfield,
processes.parent.scalars.idb_failure_fileinfo_error AS scalar_parent_idb_failure_fileinfo_error,
processes.parent.scalars.idb_type_persistent_count AS scalar_parent_idb_type_persistent_count,
processes.parent.scalars.idb_type_temporary_count AS scalar_parent_idb_type_temporary_count,
processes.parent.scalars.identity_fxaccounts_missed_commands_fetched AS scalar_parent_identity_fxaccounts_missed_commands_fetched,
processes.parent.scalars.images_webp_content_observed AS scalar_parent_images_webp_content_observed,
processes.parent.scalars.images_webp_probe_observed AS scalar_parent_images_webp_probe_observed,
processes.parent.scalars.media_allowed_autoplay_no_audio_track_count AS scalar_parent_media_allowed_autoplay_no_audio_track_count,
processes.parent.scalars.media_autoplay_default_blocked AS scalar_parent_media_autoplay_default_blocked,
processes.parent.scalars.media_autoplay_would_be_allowed_count AS scalar_parent_media_autoplay_would_be_allowed_count,
processes.parent.scalars.media_autoplay_would_not_be_allowed_count AS scalar_parent_media_autoplay_would_not_be_allowed_count,
processes.parent.scalars.media_blocked_no_metadata AS scalar_parent_media_blocked_no_metadata,
processes.parent.scalars.media_blocked_no_metadata_endup_no_audio_track AS scalar_parent_media_blocked_no_metadata_endup_no_audio_track,
processes.parent.scalars.media_page_count AS scalar_parent_media_page_count,
processes.parent.scalars.media_page_had_media_count AS scalar_parent_media_page_had_media_count,
processes.parent.scalars.media_page_had_play_revoked_count AS scalar_parent_media_page_had_play_revoked_count,
processes.parent.scalars.mediarecorder_recording_count AS scalar_parent_mediarecorder_recording_count,
processes.parent.scalars.navigator_storage_estimate_count AS scalar_parent_navigator_storage_estimate_count,
processes.parent.scalars.navigator_storage_persist_count AS scalar_parent_navigator_storage_persist_count,
processes.parent.scalars.network_tcp_overlapped_io_canceled_before_finished AS scalar_parent_network_tcp_overlapped_io_canceled_before_finished,
processes.parent.scalars.network_tcp_overlapped_result_delayed AS scalar_parent_network_tcp_overlapped_result_delayed,
processes.parent.scalars.networking_data_transferred_captive_portal AS scalar_parent_networking_data_transferred_captive_portal,
processes.parent.scalars.networking_http_connections_captive_portal AS scalar_parent_networking_http_connections_captive_portal,
processes.parent.scalars.networking_http_transactions_captive_portal AS scalar_parent_networking_http_transactions_captive_portal,
processes.parent.scalars.os_environment_is_admin_without_uac AS scalar_parent_os_environment_is_admin_without_uac,
processes.parent.scalars.pdf_viewer_fallback_shown AS scalar_parent_pdf_viewer_fallback_shown,
processes.parent.scalars.pdf_viewer_print AS scalar_parent_pdf_viewer_print,
processes.parent.scalars.pdf_viewer_used AS scalar_parent_pdf_viewer_used,
processes.parent.scalars.preferences_created_new_user_prefs_file AS scalar_parent_preferences_created_new_user_prefs_file,
processes.parent.scalars.preferences_prefs_file_was_invalid AS scalar_parent_preferences_prefs_file_was_invalid,
processes.parent.scalars.preferences_prevent_accessibility_services AS scalar_parent_preferences_prevent_accessibility_services,
processes.parent.scalars.preferences_read_user_js AS scalar_parent_preferences_read_user_js,
processes.parent.scalars.screenshots_copy AS scalar_parent_screenshots_copy,
processes.parent.scalars.screenshots_download AS scalar_parent_screenshots_download,
processes.parent.scalars.screenshots_upload AS scalar_parent_screenshots_upload,
processes.parent.scalars.script_preloader_mainthread_recompile AS scalar_parent_script_preloader_mainthread_recompile,
processes.parent.scalars.security_intermediate_preloading_num_pending AS scalar_parent_security_intermediate_preloading_num_pending,
processes.parent.scalars.security_intermediate_preloading_num_preloaded AS scalar_parent_security_intermediate_preloading_num_preloaded,
processes.parent.scalars.services_sync_fxa_verification_method AS scalar_parent_services_sync_fxa_verification_method,
processes.parent.scalars.startup_is_cold AS scalar_parent_startup_is_cold,
processes.parent.scalars.startup_profile_selection_reason AS scalar_parent_startup_profile_selection_reason,
processes.parent.scalars.storage_sync_api_usage_extensions_using AS scalar_parent_storage_sync_api_usage_extensions_using,
processes.parent.scalars.sw_alternative_body_used_count AS scalar_parent_sw_alternative_body_used_count,
processes.parent.scalars.sw_cors_res_for_so_req_count AS scalar_parent_sw_cors_res_for_so_req_count,
processes.parent.scalars.sw_synthesized_res_count AS scalar_parent_sw_synthesized_res_count,
processes.parent.scalars.telemetry_about_telemetry_pageload AS scalar_parent_telemetry_about_telemetry_pageload,
processes.parent.scalars.telemetry_data_upload_optin AS scalar_parent_telemetry_data_upload_optin,
processes.parent.scalars.telemetry_ecosystem_new_send_time AS scalar_parent_telemetry_ecosystem_new_send_time,
processes.parent.scalars.telemetry_ecosystem_old_send_time AS scalar_parent_telemetry_ecosystem_old_send_time,
processes.parent.scalars.telemetry_os_shutting_down AS scalar_parent_telemetry_os_shutting_down,
processes.parent.scalars.telemetry_pending_operations_highwatermark_reached AS scalar_parent_telemetry_pending_operations_highwatermark_reached,
processes.parent.scalars.telemetry_persistence_timer_hit_count AS scalar_parent_telemetry_persistence_timer_hit_count,
processes.parent.scalars.telemetry_process_creation_timestamp_inconsistent AS scalar_parent_telemetry_process_creation_timestamp_inconsistent,
processes.parent.scalars.telemetry_profile_directory_scan_date AS scalar_parent_telemetry_profile_directory_scan_date,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.parent.scalars.telemetry_profile_directory_scans') AS INT64) AS scalar_parent_telemetry_profile_directory_scans,
processes.parent.scalars.timestamps_about_home_topsites_first_paint AS scalar_parent_timestamps_about_home_topsites_first_paint,
processes.parent.scalars.timestamps_first_paint AS scalar_parent_timestamps_first_paint,
processes.parent.scalars.update_session_downloads_bits_complete_bytes AS scalar_parent_update_session_downloads_bits_complete_bytes,
processes.parent.scalars.update_session_downloads_bits_complete_seconds AS scalar_parent_update_session_downloads_bits_complete_seconds,
processes.parent.scalars.update_session_downloads_bits_partial_bytes AS scalar_parent_update_session_downloads_bits_partial_bytes,
processes.parent.scalars.update_session_downloads_bits_partial_seconds AS scalar_parent_update_session_downloads_bits_partial_seconds,
processes.parent.scalars.update_session_downloads_internal_complete_bytes AS scalar_parent_update_session_downloads_internal_complete_bytes,
processes.parent.scalars.update_session_downloads_internal_complete_seconds AS scalar_parent_update_session_downloads_internal_complete_seconds,
processes.parent.scalars.update_session_downloads_internal_partial_bytes AS scalar_parent_update_session_downloads_internal_partial_bytes,
processes.parent.scalars.update_session_downloads_internal_partial_seconds AS scalar_parent_update_session_downloads_internal_partial_seconds,
processes.parent.scalars.update_session_from_app_version AS scalar_parent_update_session_from_app_version,
processes.parent.scalars.update_session_intervals_apply_complete AS scalar_parent_update_session_intervals_apply_complete,
processes.parent.scalars.update_session_intervals_apply_partial AS scalar_parent_update_session_intervals_apply_partial,
processes.parent.scalars.update_session_intervals_check AS scalar_parent_update_session_intervals_check,
processes.parent.scalars.update_session_intervals_download_bits_complete AS scalar_parent_update_session_intervals_download_bits_complete,
processes.parent.scalars.update_session_intervals_download_bits_partial AS scalar_parent_update_session_intervals_download_bits_partial,
processes.parent.scalars.update_session_intervals_download_internal_complete AS scalar_parent_update_session_intervals_download_internal_complete,
processes.parent.scalars.update_session_intervals_download_internal_partial AS scalar_parent_update_session_intervals_download_internal_partial,
processes.parent.scalars.update_session_intervals_stage_complete AS scalar_parent_update_session_intervals_stage_complete,
processes.parent.scalars.update_session_intervals_stage_partial AS scalar_parent_update_session_intervals_stage_partial,
processes.parent.scalars.update_session_mar_complete_size_bytes AS scalar_parent_update_session_mar_complete_size_bytes,
processes.parent.scalars.update_session_mar_partial_size_bytes AS scalar_parent_update_session_mar_partial_size_bytes,
processes.parent.scalars.update_startup_downloads_bits_complete_bytes AS scalar_parent_update_startup_downloads_bits_complete_bytes,
processes.parent.scalars.update_startup_downloads_bits_complete_seconds AS scalar_parent_update_startup_downloads_bits_complete_seconds,
processes.parent.scalars.update_startup_downloads_bits_partial_bytes AS scalar_parent_update_startup_downloads_bits_partial_bytes,
processes.parent.scalars.update_startup_downloads_bits_partial_seconds AS scalar_parent_update_startup_downloads_bits_partial_seconds,
processes.parent.scalars.update_startup_downloads_internal_complete_bytes AS scalar_parent_update_startup_downloads_internal_complete_bytes,
processes.parent.scalars.update_startup_downloads_internal_complete_seconds AS scalar_parent_update_startup_downloads_internal_complete_seconds,
processes.parent.scalars.update_startup_downloads_internal_partial_bytes AS scalar_parent_update_startup_downloads_internal_partial_bytes,
processes.parent.scalars.update_startup_downloads_internal_partial_seconds AS scalar_parent_update_startup_downloads_internal_partial_seconds,
processes.parent.scalars.update_startup_from_app_version AS scalar_parent_update_startup_from_app_version,
processes.parent.scalars.update_startup_intervals_apply_complete AS scalar_parent_update_startup_intervals_apply_complete,
processes.parent.scalars.update_startup_intervals_apply_partial AS scalar_parent_update_startup_intervals_apply_partial,
processes.parent.scalars.update_startup_intervals_check AS scalar_parent_update_startup_intervals_check,
processes.parent.scalars.update_startup_intervals_download_bits_complete AS scalar_parent_update_startup_intervals_download_bits_complete,
processes.parent.scalars.update_startup_intervals_download_bits_partial AS scalar_parent_update_startup_intervals_download_bits_partial,
processes.parent.scalars.update_startup_intervals_download_internal_complete AS scalar_parent_update_startup_intervals_download_internal_complete,
processes.parent.scalars.update_startup_intervals_download_internal_partial AS scalar_parent_update_startup_intervals_download_internal_partial,
processes.parent.scalars.update_startup_intervals_stage_complete AS scalar_parent_update_startup_intervals_stage_complete,
processes.parent.scalars.update_startup_intervals_stage_partial AS scalar_parent_update_startup_intervals_stage_partial,
processes.parent.scalars.update_startup_mar_complete_size_bytes AS scalar_parent_update_startup_mar_complete_size_bytes,
processes.parent.scalars.update_startup_mar_partial_size_bytes AS scalar_parent_update_startup_mar_partial_size_bytes,
processes.parent.scalars.webrtc_nicer_stun_retransmits AS scalar_parent_webrtc_nicer_stun_retransmits,
processes.parent.scalars.webrtc_nicer_turn_401s AS scalar_parent_webrtc_nicer_turn_401s,
processes.parent.scalars.webrtc_nicer_turn_403s AS scalar_parent_webrtc_nicer_turn_403s,
processes.parent.scalars.webrtc_nicer_turn_438s AS scalar_parent_webrtc_nicer_turn_438s,
processes.parent.scalars.webrtc_peerconnection_connected AS scalar_parent_webrtc_peerconnection_connected,
processes.parent.scalars.webrtc_peerconnection_datachannel_created AS scalar_parent_webrtc_peerconnection_datachannel_created,
processes.parent.scalars.webrtc_peerconnection_datachannel_max_life_used AS scalar_parent_webrtc_peerconnection_datachannel_max_life_used,
processes.parent.scalars.webrtc_peerconnection_datachannel_max_retx_and_life_used AS scalar_parent_webrtc_peerconnection_datachannel_max_retx_and_life_used,
processes.parent.scalars.webrtc_peerconnection_datachannel_max_retx_used AS scalar_parent_webrtc_peerconnection_datachannel_max_retx_used,
processes.parent.scalars.webrtc_peerconnection_legacy_callback_stats_used AS scalar_parent_webrtc_peerconnection_legacy_callback_stats_used,
processes.parent.scalars.webrtc_peerconnection_promise_and_callback_stats_used AS scalar_parent_webrtc_peerconnection_promise_and_callback_stats_used,
processes.parent.scalars.webrtc_peerconnection_promise_stats_used AS scalar_parent_webrtc_peerconnection_promise_stats_used,
processes.content.scalars.browser_feeds_preview_loaded AS scalar_content_browser_feeds_preview_loaded,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.content.scalars.browser_usage_graphite') AS INT64) AS scalar_content_browser_usage_graphite,
processes.content.scalars.browser_usage_plugin_instantiated AS scalar_content_browser_usage_plugin_instantiated,
processes.content.scalars.encoding_override_used AS scalar_content_encoding_override_used,
processes.content.scalars.gfx_omtp_paint_wait_ratio AS scalar_content_gfx_omtp_paint_wait_ratio,
processes.content.scalars.idb_type_persistent_count AS scalar_content_idb_type_persistent_count,
processes.content.scalars.idb_type_temporary_count AS scalar_content_idb_type_temporary_count,
processes.content.scalars.images_webp_content_observed AS scalar_content_images_webp_content_observed,
processes.content.scalars.images_webp_probe_observed AS scalar_content_images_webp_probe_observed,
processes.content.scalars.mathml_doc_count AS scalar_content_mathml_doc_count,
processes.content.scalars.media_allowed_autoplay_no_audio_track_count AS scalar_content_media_allowed_autoplay_no_audio_track_count,
processes.content.scalars.media_autoplay_default_blocked AS scalar_content_media_autoplay_default_blocked,
processes.content.scalars.media_autoplay_would_be_allowed_count AS scalar_content_media_autoplay_would_be_allowed_count,
processes.content.scalars.media_autoplay_would_not_be_allowed_count AS scalar_content_media_autoplay_would_not_be_allowed_count,
processes.content.scalars.media_blocked_no_metadata AS scalar_content_media_blocked_no_metadata,
processes.content.scalars.media_blocked_no_metadata_endup_no_audio_track AS scalar_content_media_blocked_no_metadata_endup_no_audio_track,
processes.content.scalars.media_page_count AS scalar_content_media_page_count,
processes.content.scalars.media_page_had_media_count AS scalar_content_media_page_had_media_count,
processes.content.scalars.media_page_had_play_revoked_count AS scalar_content_media_page_had_play_revoked_count,
processes.content.scalars.mediarecorder_recording_count AS scalar_content_mediarecorder_recording_count,
processes.content.scalars.memoryreporter_max_ghost_windows AS scalar_content_memoryreporter_max_ghost_windows,
processes.content.scalars.navigator_storage_estimate_count AS scalar_content_navigator_storage_estimate_count,
processes.content.scalars.navigator_storage_persist_count AS scalar_content_navigator_storage_persist_count,
processes.content.scalars.pdf_viewer_fallback_shown AS scalar_content_pdf_viewer_fallback_shown,
processes.content.scalars.pdf_viewer_print AS scalar_content_pdf_viewer_print,
processes.content.scalars.pdf_viewer_used AS scalar_content_pdf_viewer_used,
processes.content.scalars.script_preloader_mainthread_recompile AS scalar_content_script_preloader_mainthread_recompile,
processes.content.scalars.sw_alternative_body_used_count AS scalar_content_sw_alternative_body_used_count,
processes.content.scalars.sw_cors_res_for_so_req_count AS scalar_content_sw_cors_res_for_so_req_count,
processes.content.scalars.sw_synthesized_res_count AS scalar_content_sw_synthesized_res_count,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.content.scalars.telemetry_discarded_accumulations') AS INT64) AS scalar_content_telemetry_discarded_accumulations,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.content.scalars.telemetry_discarded_child_events') AS INT64) AS scalar_content_telemetry_discarded_child_events,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.content.scalars.telemetry_discarded_keyed_accumulations') AS INT64) AS scalar_content_telemetry_discarded_keyed_accumulations,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.content.scalars.telemetry_discarded_keyed_scalar_actions') AS INT64) AS scalar_content_telemetry_discarded_keyed_scalar_actions,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.content.scalars.telemetry_discarded_scalar_actions') AS INT64) AS scalar_content_telemetry_discarded_scalar_actions,
processes.content.scalars.telemetry_process_creation_timestamp_inconsistent AS scalar_content_telemetry_process_creation_timestamp_inconsistent,
CAST(JSON_EXTRACT(additional_properties, '$.payload.processes.content.scalars.telemetry_profile_directory_scans') AS INT64) AS scalar_content_telemetry_profile_directory_scans,
processes.content.scalars.webrtc_nicer_stun_retransmits AS scalar_content_webrtc_nicer_stun_retransmits,
processes.content.scalars.webrtc_nicer_turn_401s AS scalar_content_webrtc_nicer_turn_401s,
processes.content.scalars.webrtc_nicer_turn_403s AS scalar_content_webrtc_nicer_turn_403s,
processes.content.scalars.webrtc_nicer_turn_438s AS scalar_content_webrtc_nicer_turn_438s,
processes.content.scalars.webrtc_peerconnection_connected AS scalar_content_webrtc_peerconnection_connected,
processes.content.scalars.webrtc_peerconnection_datachannel_created AS scalar_content_webrtc_peerconnection_datachannel_created,
processes.content.scalars.webrtc_peerconnection_datachannel_max_life_used AS scalar_content_webrtc_peerconnection_datachannel_max_life_used,
processes.content.scalars.webrtc_peerconnection_datachannel_max_retx_and_life_used AS scalar_content_webrtc_peerconnection_datachannel_max_retx_and_life_used,
processes.content.scalars.webrtc_peerconnection_datachannel_max_retx_used AS scalar_content_webrtc_peerconnection_datachannel_max_retx_used,
processes.content.scalars.webrtc_peerconnection_legacy_callback_stats_used AS scalar_content_webrtc_peerconnection_legacy_callback_stats_used,
processes.content.scalars.webrtc_peerconnection_promise_and_callback_stats_used AS scalar_content_webrtc_peerconnection_promise_and_callback_stats_used,
processes.content.scalars.webrtc_peerconnection_promise_stats_used AS scalar_content_webrtc_peerconnection_promise_stats_used,
processes.parent.keyed_scalars.a11y_theme AS scalar_parent_a11y_theme,
processes.parent.keyed_scalars.browser_engagement_navigation_about_home AS scalar_parent_browser_engagement_navigation_about_home,
processes.parent.keyed_scalars.browser_engagement_navigation_about_newtab AS scalar_parent_browser_engagement_navigation_about_newtab,
processes.parent.keyed_scalars.browser_engagement_navigation_contextmenu AS scalar_parent_browser_engagement_navigation_contextmenu,
processes.parent.keyed_scalars.browser_engagement_navigation_searchbar AS scalar_parent_browser_engagement_navigation_searchbar,
processes.parent.keyed_scalars.browser_engagement_navigation_urlbar AS scalar_parent_browser_engagement_navigation_urlbar,
processes.parent.keyed_scalars.browser_engagement_navigation_webextension AS scalar_parent_browser_engagement_navigation_webextension,
processes.parent.keyed_scalars.browser_errors_collected_count_by_filename AS scalar_parent_browser_errors_collected_count_by_filename,
processes.parent.keyed_scalars.browser_search_ad_clicks AS scalar_parent_browser_search_ad_clicks,
processes.parent.keyed_scalars.browser_search_with_ads AS scalar_parent_browser_search_with_ads,
processes.parent.keyed_scalars.devtools_accessibility_accessible_context_menu_item_activated AS scalar_parent_devtools_accessibility_accessible_context_menu_item_activated,
processes.parent.keyed_scalars.devtools_accessibility_audit_activated AS scalar_parent_devtools_accessibility_audit_activated,
processes.parent.keyed_scalars.devtools_accessibility_select_accessible_for_node AS scalar_parent_devtools_accessibility_select_accessible_for_node,
processes.parent.keyed_scalars.devtools_accessibility_simulation_activated AS scalar_parent_devtools_accessibility_simulation_activated,
processes.parent.keyed_scalars.devtools_current_theme AS scalar_parent_devtools_current_theme,
processes.parent.keyed_scalars.devtools_inspector_three_pane_enabled AS scalar_parent_devtools_inspector_three_pane_enabled,
processes.parent.keyed_scalars.devtools_responsive_open_trigger AS scalar_parent_devtools_responsive_open_trigger,
processes.parent.keyed_scalars.devtools_tool_registered AS scalar_parent_devtools_tool_registered,
processes.parent.keyed_scalars.devtools_toolbox_tabs_reordered AS scalar_parent_devtools_toolbox_tabs_reordered,
processes.parent.keyed_scalars.devtools_tooltip_shown AS scalar_parent_devtools_tooltip_shown,
processes.parent.keyed_scalars.extensions_updates_rdf AS scalar_parent_extensions_updates_rdf,
processes.parent.keyed_scalars.gfx_advanced_layers_failure_id AS scalar_parent_gfx_advanced_layers_failure_id,
processes.parent.keyed_scalars.images_webp_content_frequency AS scalar_parent_images_webp_content_frequency,
processes.parent.keyed_scalars.networking_data_transferred_kb AS scalar_parent_networking_data_transferred_kb,
processes.parent.keyed_scalars.networking_data_transferred_v3_kb AS scalar_parent_networking_data_transferred_v3_kb,
processes.parent.keyed_scalars.normandy_recipe_freshness AS scalar_parent_normandy_recipe_freshness,
processes.parent.keyed_scalars.pictureinpicture_closed_method AS scalar_parent_pictureinpicture_closed_method,
processes.parent.keyed_scalars.preferences_browser_home_page_change AS scalar_parent_preferences_browser_home_page_change,
processes.parent.keyed_scalars.preferences_browser_home_page_count AS scalar_parent_preferences_browser_home_page_count,
processes.parent.keyed_scalars.preferences_search_query AS scalar_parent_preferences_search_query,
processes.parent.keyed_scalars.preferences_use_bookmark AS scalar_parent_preferences_use_bookmark,
processes.parent.keyed_scalars.preferences_use_current_page AS scalar_parent_preferences_use_current_page,
processes.parent.keyed_scalars.qm_origin_directory_unexpected_filename AS scalar_parent_qm_origin_directory_unexpected_filename,
processes.parent.keyed_scalars.resistfingerprinting_content_window_size AS scalar_parent_resistfingerprinting_content_window_size,
processes.parent.keyed_scalars.sandbox_no_job AS scalar_parent_sandbox_no_job,
processes.parent.keyed_scalars.security_client_cert AS scalar_parent_security_client_cert,
processes.parent.keyed_scalars.security_pkcs11_modules_loaded AS scalar_parent_security_pkcs11_modules_loaded,
processes.parent.keyed_scalars.security_webauthn_used AS scalar_parent_security_webauthn_used,
processes.parent.keyed_scalars.services_sync_sync_login_state_transitions AS scalar_parent_services_sync_sync_login_state_transitions,
processes.parent.keyed_scalars.storage_sync_api_usage_items_stored AS scalar_parent_storage_sync_api_usage_items_stored,
processes.parent.keyed_scalars.storage_sync_api_usage_storage_consumed AS scalar_parent_storage_sync_api_usage_storage_consumed,
processes.parent.keyed_scalars.telemetry_accumulate_clamped_values AS scalar_parent_telemetry_accumulate_clamped_values,
udf_json_extract_string_int_map(JSON_EXTRACT(additional_properties, '$.payload.processes.parent.keyed_scalars.telemetry_accumulate_unknown_histogram_keys')) AS scalar_parent_telemetry_accumulate_unknown_histogram_keys,
udf_json_extract_string_int_map(JSON_EXTRACT(additional_properties, '$.payload.processes.parent.keyed_scalars.telemetry_event_counts')) AS scalar_parent_telemetry_event_counts,
processes.parent.keyed_scalars.telemetry_keyed_scalars_exceed_limit AS scalar_parent_telemetry_keyed_scalars_exceed_limit,
processes.parent.keyed_scalars.update_binarytransparencyresult AS scalar_parent_update_binarytransparencyresult,
processes.parent.keyed_scalars.update_bitshresult AS scalar_parent_update_bitshresult,
processes.parent.keyed_scalars.widget_ime_name_on_linux AS scalar_parent_widget_ime_name_on_linux,
processes.parent.keyed_scalars.widget_ime_name_on_mac AS scalar_parent_widget_ime_name_on_mac,
processes.parent.keyed_scalars.widget_ime_name_on_windows AS scalar_parent_widget_ime_name_on_windows,
processes.content.keyed_scalars.dom_event_confluence_load_count AS scalar_content_dom_event_confluence_load_count,
processes.content.keyed_scalars.dom_event_office_online_load_count AS scalar_content_dom_event_office_online_load_count,
processes.content.keyed_scalars.gfx_small_paint_phase_weight AS scalar_content_gfx_small_paint_phase_weight,
processes.content.keyed_scalars.images_webp_content_frequency AS scalar_content_images_webp_content_frequency,
processes.content.keyed_scalars.pictureinpicture_opened_method AS scalar_content_pictureinpicture_opened_method,
udf_json_extract_string_int_map(JSON_EXTRACT(additional_properties, '$.payload.processes.content.keyed_scalars.telemetry_accumulate_unknown_histogram_keys')) AS scalar_content_telemetry_accumulate_unknown_histogram_keys,
udf_json_extract_string_int_map(JSON_EXTRACT(additional_properties, '$.payload.processes.content.keyed_scalars.telemetry_event_counts')) AS scalar_content_telemetry_event_counts,
processes.content.keyed_scalars.webrtc_sdp_parser_diff AS scalar_content_webrtc_sdp_parser_diff,
processes.content.keyed_scalars.webrtc_video_recv_codec_used AS scalar_content_webrtc_video_recv_codec_used,
processes.content.keyed_scalars.webrtc_video_send_codec_used AS scalar_content_webrtc_video_send_codec_used
  ));
--
SELECT
  document_id,
  client_id,
  sample_id,
  metadata.uri.app_update_channel AS channel,
  normalized_channel,
  normalized_os_version,
  metadata.geo.country,
  metadata.geo.city,
  metadata.geo.subdivision1 AS geo_subdivision1,
  metadata.geo.subdivision2 AS geo_subdivision2,
  environment.system.os.name AS os,
  JSON_EXTRACT_SCALAR(additional_properties, "$.environment.system.os.version") AS os_version,
  SAFE_CAST(environment.system.os.service_pack_major AS INT64) AS os_service_pack_major,
  SAFE_CAST(environment.system.os.service_pack_minor AS INT64) AS os_service_pack_minor,
  SAFE_CAST(environment.system.os.windows_build_number AS INT64) AS windows_build_number,
  SAFE_CAST(environment.system.os.windows_ubr AS INT64) AS windows_ubr,

  -- Note: Windows only!
  SAFE_CAST(environment.system.os.install_year AS INT64) AS install_year,
  environment.system.is_wow64,

  SAFE_CAST(environment.system.memory_mb AS INT64) AS memory_mb,

  environment.system.cpu.count AS cpu_count,
  environment.system.cpu.cores AS cpu_cores,
  environment.system.cpu.vendor AS cpu_vendor,
  environment.system.cpu.family AS cpu_family,
  environment.system.cpu.model AS cpu_model,
  environment.system.cpu.stepping AS cpu_stepping,
  SAFE_CAST(environment.system.cpu.l2cache_kb AS INT64) AS cpu_l2_cache_kb,
  SAFE_CAST(environment.system.cpu.l3cache_kb AS INT64) AS cpu_l3_cache_kb,
  SAFE_CAST(environment.system.cpu.speed_m_hz AS INT64) AS cpu_speed_mhz,

  environment.system.gfx.features.d3d11.status AS gfx_features_d3d11_status,
  environment.system.gfx.features.d2d.status AS gfx_features_d2d_status,
  environment.system.gfx.features.gpu_process.status AS gfx_features_gpu_process_status,
  environment.system.gfx.features.advanced_layers.status AS gfx_features_advanced_layers_status,
  JSON_EXTRACT_SCALAR(additional_properties, "$.environment.system.gfx.features.wr_qualified.status") AS gfx_features_wrqualified_status,
  JSON_EXTRACT_SCALAR(additional_properties, "$.environment.system.gfx.features.webrender.status") AS gfx_features_webrender_status,

  -- Bug 1552940
  environment.system.hdd.profile.type AS hdd_profile_type,
  environment.system.hdd.binary.type AS hdd_binary_type,
  environment.system.hdd.system.type AS hdd_system_type,

  environment.system.apple_model_id,

  -- Bug 1431198 - Windows 8 only
  environment.system.sec.antivirus,
  environment.system.sec.antispyware,
  environment.system.sec.firewall,

  -- TODO: use proper 'date' type for date columns.
  SAFE_CAST(environment.profile.creation_date AS INT64) AS profile_creation_date,
  SAFE_CAST(environment.profile.reset_date AS INT64) AS profile_reset_date,
  JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.previous_build_id") AS previous_build_id,
  JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.session_id") AS session_id,
  JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.subsession_id") AS subsession_id,
  JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.previous_subsession_id") AS previous_subsession_id,
  JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.session_start_date") AS session_start_date,
  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.session_length") AS INT64) AS session_length,
  payload.info.subsession_length,
  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.subsession_counter") AS INT64) AS subsession_counter,
  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.profile_subsession_counter") AS INT64) AS profile_subsession_counter,
  creation_date,
  environment.partner.distribution_id,
  DATE(submission_timestamp) AS submission_date,
  -- See bug 1550752
  udf_boolean_histogram_to_boolean(payload.histograms.fxa_configured) AS fxa_configured,
  -- See bug 1232050
  udf_boolean_histogram_to_boolean(payload.histograms.weave_configured) AS sync_configured,
  udf_enum_histogram_to_count(payload.histograms.weave_device_count_desktop) AS sync_count_desktop,
  udf_enum_histogram_to_count(payload.histograms.weave_device_count_mobile) AS sync_count_mobile,

  application.build_id AS app_build_id,
  application.display_version AS app_display_version,
  application.name AS app_name,
  application.version AS app_version,
  UNIX_MICROS(submission_timestamp) * 1000 AS `timestamp`,

  environment.build.build_id AS env_build_id,
  environment.build.version AS env_build_version,
  environment.build.architecture AS env_build_arch,

  -- See bug 1232050
  environment.settings.e10s_enabled,

  -- See bug 1232050
  environment.settings.e10s_multi_processes,

  environment.settings.locale,
  environment.settings.update.channel AS update_channel,
  environment.settings.update.enabled AS update_enabled,
  environment.settings.update.auto_download AS update_auto_download,
  STRUCT(environment.settings.attribution.source, environment.settings.attribution.medium, environment.settings.attribution.campaign, environment.settings.attribution.content) AS attribution,
  environment.settings.sandbox.effective_content_process_level AS sandbox_effective_content_process_level,
  environment.addons.active_experiment.id AS active_experiment_id,
  environment.addons.active_experiment.branch AS active_experiment_branch,
  JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.reason") AS reason,

  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.info.timezone_offset") AS INT64) AS timezone_offset,

  -- Different types of crashes / hangs:
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_crashes_with_dump, "pluginhang")).sum AS plugin_hangs,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_abnormal_abort, "plugin")).sum AS aborts_plugin,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_abnormal_abort, "content")).sum AS aborts_content,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_abnormal_abort, "gmplugin")).sum AS aborts_gmplugin,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_crashes_with_dump, "plugin")).sum AS crashes_detected_plugin,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_crashes_with_dump, "content")).sum AS crashes_detected_content,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_crashes_with_dump, "gmplugin")).sum AS crashes_detected_gmplugin,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.process_crash_submit_attempt, "main_crash")).sum AS crash_submit_attempt_main,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.process_crash_submit_attempt, "content_crash")).sum AS crash_submit_attempt_content,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.process_crash_submit_attempt, "plugin_crash")).sum AS crash_submit_attempt_plugin,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.process_crash_submit_success, "main_crash")).sum AS crash_submit_success_main,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.process_crash_submit_success, "content_crash")).sum AS crash_submit_success_content,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.process_crash_submit_success, "plugin_crash")).sum AS crash_submit_success_plugin,
  udf_json_extract_histogram(udf_get_key(payload.keyed_histograms.subprocess_kill_hard, "shut_down_kill")).sum AS shutdown_kill,

  ARRAY_LENGTH(environment.addons.active_addons) AS active_addons_count,

  -- See https://github.com/mozilla-services/data-pipeline/blob/master/hindsight/modules/fx/ping.lua#L82
  udf_max_flash_version(environment.addons.active_plugins) AS flash_version, -- latest installable version of flash plugin.
  application.vendor,
  environment.settings.is_default_browser,
  environment.settings.default_search_engine_data.name AS default_search_engine_data_name,
  environment.settings.default_search_engine_data.load_path AS default_search_engine_data_load_path,
  environment.settings.default_search_engine_data.origin AS default_search_engine_data_origin,
  environment.settings.default_search_engine_data.submission_url AS default_search_engine_data_submission_url,
  environment.settings.default_search_engine,

  -- DevTools usage per bug 1262478
  udf_json_extract_histogram(payload.histograms.devtools_toolbox_opened_count).sum AS devtools_toolbox_opened_count,

  -- client date per bug 1270505
  metadata.header.date AS client_submission_date, -- the HTTP Date header sent by the client

  -- clock skew per bug 1270183
  TIMESTAMP_DIFF(SAFE.PARSE_TIMESTAMP("%a, %d %b %Y %T %Z", metadata.header.date), submission_timestamp, SECOND) AS client_clock_skew,
  TIMESTAMP_DIFF(SAFE.PARSE_TIMESTAMP("%FT%R:%E*SZ", creation_date), submission_timestamp, SECOND) AS client_submission_latency,

  -- We use the mean for bookmarks and pages because we do not expect them to be
  -- heavily skewed during the lifetime of a subsession. Using the median for a
  -- histogram would probably be better in general, but the granularity of the
  -- buckets for these particular histograms is not fine enough for the median
  -- to give a more accurate value than the mean.
  (SELECT SAFE_CAST(AVG(value) AS INT64) FROM UNNEST(udf_json_extract_histogram(payload.histograms.places_bookmarks_count).values)) AS places_bookmarks_count,
  (SELECT SAFE_CAST(AVG(value) AS INT64) FROM UNNEST(udf_json_extract_histogram(payload.histograms.places_pages_count).values)) AS places_pages_count,

  -- Push metrics per bug 1270482 and bug 1311174
  udf_json_extract_histogram(payload.histograms.push_api_notify).sum AS push_api_notify,
  udf_json_extract_histogram(payload.histograms.web_notification_shown).sum AS web_notification_shown,

  -- Info from POPUP_NOTIFICATION_STATS keyed histogram
  udf_get_popup_notification_stats(payload.keyed_histograms.popup_notification_stats) AS popup_notification_stats,

  -- Search counts
  -- split up and organize the SEARCH_COUNTS keyed histogram
  udf_get_search_counts(payload.keyed_histograms.search_counts) AS search_counts,

  -- Addon and configuration settings per Bug 1290181
  udf_js_get_active_addons(environment.addons.active_addons, JSON_EXTRACT(additional_properties, "$.environment.addons.activeAddons")) AS active_addons,

  -- Legacy/disabled addon and configuration settings per Bug 1390814. Please note that |disabled_addons_ids| may go away in the future.
  udf_js_get_disabled_addons(environment.addons.active_addons, JSON_EXTRACT(additional_properties, "$.payload.addon_details")) AS disabled_addons_ids, -- One per item in payload.addonDetails.XPI
  STRUCT(
    environment.addons.theme.app_disabled as app_disabled,
    environment.addons.theme.blocklisted as blocklisted,
    environment.addons.theme.description as description,
    environment.addons.theme.has_binary_components as has_binary_components,
    IFNULL(environment.addons.theme.id, "MISSING") as id,
    environment.addons.theme.install_day as install_day,
    environment.addons.theme.name as name,
    environment.addons.theme.scope as scope,
    environment.addons.theme.update_day as update_day,
    environment.addons.theme.user_disabled as user_disabled,
    environment.addons.theme.version as version
  ) AS active_theme,
  environment.settings.blocklist_enabled,
  environment.settings.addon_compatibility_check_enabled,
  environment.settings.telemetry_enabled,

  environment.settings.intl.accept_languages AS environment_settings_intl_accept_languages,
  environment.settings.intl.app_locales AS environment_settings_intl_app_locales,
  environment.settings.intl.available_locales AS environment_settings_intl_available_locales,
  environment.settings.intl.regional_prefs_locales AS environment_settings_intl_regional_prefs_locales,
  environment.settings.intl.requested_locales AS environment_settings_intl_requested_locales,
  environment.settings.intl.system_locales AS environment_settings_intl_system_locales,

  environment.system.gfx.headless AS environment_system_gfx_headless,

  -- TODO: Deprecate and eventually remove this field, preferring the top-level user_pref_* fields for easy schema evolution.
  udf_get_old_user_prefs(JSON_EXTRACT(additional_properties, "$.environment.settings.user_prefs")) AS user_prefs,

  udf_js_get_events([
   ("content", JSON_EXTRACT(additional_properties, "$.payload.processes.content.events")),
   ("dynamic", JSON_EXTRACT(additional_properties, "$.payload.processes.dynamic.events")),
   ("gfx", JSON_EXTRACT(additional_properties, "$.payload.processes.gfx.events")),
   ("parent", JSON_EXTRACT(additional_properties, "$.payload.processes.parent.events"))]) AS events,

  -- bug 1339655
  SAFE_CAST(JSON_EXTRACT_SCALAR(payload.histograms.ssl_handshake_result, "$.values.0") AS INT64) AS ssl_handshake_result_success,
  (SELECT SUM(value) FROM UNNEST(udf_json_extract_histogram(payload.histograms.ssl_handshake_result).values) WHERE key BETWEEN 1 AND 671) AS ssl_handshake_result_failure,
  (SELECT STRUCT(CAST(key AS STRING) AS key, value) FROM UNNEST(udf_json_extract_histogram(payload.histograms.ssl_handshake_result).values) WHERE key BETWEEN 0 AND 671) AS ssl_handshake_result,

  -- bug 1353114 - payload.simpleMeasurements.*
  COALESCE(
    payload.processes.parent.scalars.browser_engagement_active_ticks,
    SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.simple_measurements.active_ticks") AS INT64)) AS active_ticks,
  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.simple_measurements.main") AS INT64) AS main,
  COALESCE(
    payload.processes.parent.scalars.timestamps_first_paint,
    SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.simple_measurements.first_paint") AS INT64)) AS first_paint,
  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.simple_measurements.session_restored") AS INT64) AS session_restored,
  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.simple_measurements.total_time") AS INT64) AS total_time,
  SAFE_CAST(JSON_EXTRACT_SCALAR(additional_properties, "$.payload.simple_measurements.blank_window_shown") AS INT64) AS blank_window_shown,

  -- bug 1362520 and 1526278 - plugin notifications
  SAFE_CAST(JSON_EXTRACT_SCALAR(payload.histograms.plugins_notification_user_action, "$.values.1") AS INT64) AS plugins_notification_shown,
  SAFE_CAST(JSON_EXTRACT_SCALAR(payload.histograms.plugins_notification_user_action, "$.values.0") AS INT64) AS plugins_notification_false,
  udf_get_plugins_notification_user_action(payload.histograms.plugins_notification_user_action) AS plugins_notification_user_action,
  udf_json_extract_histogram(payload.histograms.plugins_infobar_shown).sum AS plugins_infobar_shown,
  udf_json_extract_histogram(payload.histograms.plugins_infobar_block).sum AS plugins_infobar_block,
  udf_json_extract_histogram(payload.histograms.plugins_infobar_allow).sum AS plugins_infobar_allow,
  udf_json_extract_histogram(payload.histograms.plugins_infobar_dismissed).sum AS plugins_infobar_dismissed,

  -- bug 1366253 - active experiments
  udf_get_experiments(environment.experiments), -- experiment id->branchname

  environment.settings.search_cohort,

  -- bug 1366838 - Quantum Release Criteria
  environment.system.gfx.features.compositor AS gfx_compositor,
  udf_js_get_quantum_ready(environment.settings.e10s_enabled, environment.addons.active_addons, JSON_EXTRACT(additional_properties, "$.environment.addons.activeAddons"), environment.addons.theme) AS quantum_ready,

  udf_histogram_to_threshold_count(payload.histograms.gc_max_pause_ms_2, 150),
  udf_histogram_to_threshold_count(payload.histograms.gc_max_pause_ms_2, 250),
  udf_histogram_to_threshold_count(payload.histograms.gc_max_pause_ms_2, 2500),

  udf_histogram_to_threshold_count(payload.processes.content.histograms.gc_max_pause_ms_2, 150),
  udf_histogram_to_threshold_count(payload.processes.content.histograms.gc_max_pause_ms_2, 250),
  udf_histogram_to_threshold_count(payload.processes.content.histograms.gc_max_pause_ms_2, 2500),

  udf_histogram_to_threshold_count(payload.histograms.cycle_collector_max_pause, 150),
  udf_histogram_to_threshold_count(payload.histograms.cycle_collector_max_pause, 250),
  udf_histogram_to_threshold_count(payload.histograms.cycle_collector_max_pause, 2500),

  udf_histogram_to_threshold_count(payload.processes.content.histograms.cycle_collector_max_pause, 150),
  udf_histogram_to_threshold_count(payload.processes.content.histograms.cycle_collector_max_pause, 250),
  udf_histogram_to_threshold_count(payload.processes.content.histograms.cycle_collector_max_pause, 2500),

  udf_histogram_to_threshold_count(payload.histograms.input_event_response_coalesced_ms, 150),
  udf_histogram_to_threshold_count(payload.histograms.input_event_response_coalesced_ms, 250),
  udf_histogram_to_threshold_count(payload.histograms.input_event_response_coalesced_ms, 2500),

  udf_histogram_to_threshold_count(payload.processes.content.histograms.input_event_response_coalesced_ms, 150),
  udf_histogram_to_threshold_count(payload.processes.content.histograms.input_event_response_coalesced_ms, 250),
  udf_histogram_to_threshold_count(payload.processes.content.histograms.input_event_response_coalesced_ms, 2500),

  udf_histogram_to_threshold_count(payload.histograms.ghost_windows, 1),
  udf_histogram_to_threshold_count(payload.processes.content.histograms.ghost_windows, 1),

  udf_get_user_prefs(JSON_EXTRACT(additional_properties, "$.environment.settings.user_prefs")).*,
  udf_scalar_row(payload.processes, additional_properties).*
FROM
  `moz-fx-data-shared-prod.telemetry_stable.main_v4`
WHERE
  DATE(submission_timestamp) = @submission_date
  AND normalized_app_name = "Firefox"
  AND document_id IS NOT NULL
