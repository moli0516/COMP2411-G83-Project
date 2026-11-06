-- Q08: Repeat repairs after an earlier closed job with first-round failure
-- Mapping: Proposed refinement of MQ04; group approval pending
-- Proposed techniques: correlated;exists;other_nontrivial
-- INCOMPLETE: no SELECT implementation.
-- TODO: fixed parameters, row meaning, null behavior and expected result.
-- TODO: author one business SELECT; add ORDER BY if order matters.
SELECT
    a.job_id
FROM vw_equipment_repair_history a
WHERE a.request_status <> 'CLOSED'
    AND EXISTS(
        SELECT 1
        FROM vw_equipment_repair_history b
        INNER JOIN 
            Inspection i ON b.job_id = i.job_id 
        INNER JOIN 
            InspectionResult ir ON ir.inspection_id = i.inspection_id 
        WHERE b.equipment_id = a.equipment_id
            AND b.request_status = "CLOSED"
            AND ir.result = "FAIL"
            AND i.inspection_round = 1
            AND b.returned_date < a.request_date
    );