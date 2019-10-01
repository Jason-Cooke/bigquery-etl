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
