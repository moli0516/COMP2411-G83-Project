-- Q02: Technician failure counts and inspected workload
-- Mapping: MQ02
-- Period: 2026-03-01 through 2026-10-31 inclusive, by inspection_date.
-- Source view retains one completed round-1 inspection per job.
-- Technique in this SELECT: group_by; joins are encapsulated by the view.
SELECT
    technician_id,
    technician_name,
    COUNT(*) AS inspected_jobs,
    SUM(CASE WHEN overall_result = 'FAIL' THEN 1 ELSE 0 END) AS inspected_failures,
    SUM(CASE WHEN overall_result = 'FAIL' THEN 1 ELSE 0 END) / COUNT(*) * 100 AS failure_percentage
FROM vw_first_round_inspection
WHERE inspection_date >= '2026-03-01'
  AND inspection_date < '2026-11-01'
GROUP BY technician_id, technician_name
ORDER BY
    inspected_failures DESC,
    failure_percentage DESC,
    technician_id ASC;
