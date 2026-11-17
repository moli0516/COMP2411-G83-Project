-- Q08: Open repeat-repair jobs after an earlier closed repair.
-- Mapping: MQ04 refinement - earlier failed first inspection.
-- One row per currently open job; correlation uses the same equipment.
-- Earlier job must be CLOSED and returned before the current request.
-- Failure means a FAIL criterion in a COMPLETED round-1 inspection.
-- Retains criterion-level meaning of the original query, not a new definition.
-- Return-date comparison excludes NULL returns. Association is not causation.
SELECT
    a.job_id
FROM vw_equipment_repair_history AS a
WHERE a.job_status <> 'CLOSED'
  AND EXISTS (
      SELECT 1
      FROM vw_equipment_repair_history AS b
      JOIN Inspection AS i
        ON i.job_id = b.job_id
      JOIN InspectionResult AS ir
        ON ir.inspection_id = i.inspection_id
      WHERE b.equipment_id = a.equipment_id
        AND b.job_status = 'CLOSED'
        AND b.returned_date < a.request_date
        AND i.inspection_round = 1
        AND i.inspection_status = 'COMPLETED'
        AND ir.result = 'FAIL'
  )
ORDER BY a.job_id ASC;
