-- Q02: Technician failure counts and inspected workload
-- Mapping: MQ02
-- Proposed techniques: join;join3plus;group_by
-- INCOMPLETE: no SELECT implementation.
-- TODO: fixed parameters, row meaning, null behavior and expected result.
-- TODO: author one business SELECT; add ORDER BY if order matters.
SELECT 
    technician_id, 
    technician_name, 
    COUNT(*) inspected_jobs, 
    SUM(CASE WHEN overall_result = "FAIL" THEN 1 ELSE 0 END) AS inspected_failures,
    SUM(CASE WHEN overall_result = "FAIL" THEN 1 ELSE 0 END) / COUNT(*) * 100 AS failure_percentage
FROM vw_first_round_inspection
GROUP BY technician_id
