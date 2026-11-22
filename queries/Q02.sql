-- Q02: First-round inspection failure counts and rates by technician.
-- Management question: MQ01 - First-round inspection performance.
-- Techniques: group_by;view
--
-- Purpose:
-- Compare inspection outcomes by the technician responsible for the job,
-- not by the staff member who performed the inspection.
--
-- Source:
-- vw_first_round_inspection supplies completed first-round inspections,
-- with one qualifying inspection row per job.
-- Joins are encapsulated by the view rather than written in this SELECT.
--
-- Population:
-- Inspection dates range from 2026-03-01 through 2026-10-31 inclusive,
-- implemented as >= '2026-03-01' AND < '2026-11-01'.
-- Technicians without qualifying inspection rows are not included.
--
-- Calculation:
-- inspected_jobs counts qualifying view rows for each technician.
-- inspected_failures sums 1 for inspection-level overall_result = FAIL
-- and 0 for other qualifying results.
-- failure_percentage = inspected_failures / inspected_jobs * 100.
-- The SELECT does not explicitly round the calculated percentage.
--
-- Output:
-- One row per responsible technician in the qualifying population.
-- Sort by failure count descending, failure percentage descending,
-- and technician_id ascending.
--
-- Retained clean-seed expectation:
-- 7 technicians, covering the same 71 inspected jobs and 30 failures
-- as Q01.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- Failure counts must be read alongside inspected-job totals.
-- These figures do not adjust for fault complexity or hardware mix
-- and are not a complete measure of technician performance.

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
