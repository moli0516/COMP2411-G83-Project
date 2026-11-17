-- Q01: First-round failure rate by hardware type
-- Mapping: MQ01
-- Proposed techniques: join;join3plus;group_by
-- Percentage denominator: distinct jobs inspected within each component type.

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
GROUP BY
    e.component_type
ORDER BY
    failure_percentage DESC,
    failed_jobs DESC,
    e.component_type ASC;