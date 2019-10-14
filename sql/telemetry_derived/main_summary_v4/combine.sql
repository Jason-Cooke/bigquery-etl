SELECT
  main_summary_v4_part1.*,
  main_summary_v4_part2.* EXCEPT(document_id)
FROM
  main_summary_v4_part1
JOIN
  main_summary_v4_part2
USING
  (document_id)
