-- Q01: First-round inspection failure counts and rates by component type.
-- Management question: MQ01 - First-round inspection performance.
-- Techniques: join;join3plus;group_by;null_handling
--
-- Purpose:
-- Compare first-round inspection outcomes across hardware component types.
--
-- Population:
-- Include only COMPLETED inspections with inspection_round = 1.
-- Inspection dates range from 2026-03-01 through 2026-10-31 inclusive,
-- implemented as >= '2026-03-01' AND < '2026-11-01'.
-- Jobs without a qualifying completed first-round inspection are excluded.
--
-- Calculation:
-- inspected_jobs counts DISTINCT job_id values within each component type.
-- failed_jobs counts DISTINCT jobs whose inspection-level overall_result
-- is FAIL; criterion-level InspectionResult rows are not used.
-- failure_percentage = 100 * failed_jobs / inspected_jobs, rounded to
-- two decimal places.
--
-- NULL handling:
-- CASE returns NULL for non-failing jobs, which COUNT ignores.
-- NULLIF protects the percentage denominator against division by zero.
--
-- Output:
-- One row per component type represented in the qualifying population.
-- Sort by failure percentage descending, failed-job count descending,
-- and component type ascending.
--
-- Retained clean-seed expectation:
-- 7 component-type groups, covering 71 inspected jobs and 30 failed jobs.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- Compare failure counts together with their inspected-job denominators.
-- Synthetic results do not establish the causes of inspection failure.

SELECT
    e.component_type,
    COUNT(DISTINCT j.job_id) AS inspected_jobs,
    COUNT(
        DISTINCT CASE
            WHEN i.overall_result = 'FAIL' THEN j.job_id
        END
    ) AS failed_jobs,
    ROUND(
        100.0
        * COUNT(
            DISTINCT CASE
                WHEN i.overall_result = 'FAIL' THEN j.job_id
            END
        )
        / NULLIF(COUNT(DISTINCT j.job_id), 0),
        2
    ) AS failure_percentage
FROM Equipment AS e
JOIN RequestItem AS ri
    ON ri.equipment_id = e.equipment_id
JOIN ServiceJob AS j
    ON j.request_item_id = ri.request_item_id
JOIN Inspection AS i
    ON i.job_id = j.job_id
WHERE i.inspection_round = 1
  AND i.inspection_status = 'COMPLETED'
  AND i.inspection_date >= '2026-03-01'
  AND i.inspection_date < '2026-11-01'
GROUP BY
    e.component_type
ORDER BY
    failure_percentage DESC,
    failed_jobs DESC,
    e.component_type ASC;