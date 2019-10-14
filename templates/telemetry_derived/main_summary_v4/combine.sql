SELECT
  part1.*,
  part2.* EXCEPT(document_id)
FROM
  part1
JOIN
  part2
USING
  (document_id)
