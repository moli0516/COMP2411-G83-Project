-- Q08: Open repeat-repair jobs with qualifying earlier inspection failures.
-- Management question: MQ02 - Repeat repairs.
-- Techniques: join;subquery;correlated;exists;view
--
-- Purpose:
-- Identify currently open jobs for equipment with an earlier closed repair
-- that included a failed first-round inspection criterion.
--
-- Source:
-- vw_equipment_repair_history supplies the current and earlier job history.
-- The correlated subquery explicitly joins Inspection and InspectionResult.
--
-- Current-job population:
-- Include history rows whose job_status <> 'CLOSED'.
-- "Open" in this query means any stored non-CLOSED job status.
-- No universal reporting-date cutoff is applied.
--
-- Qualifying earlier history:
-- The earlier job must refer to the same equipment_id.
-- Its job_status must be CLOSED.
-- Its returned_date must be strictly earlier than the current request_date.
-- It must have a COMPLETED inspection with inspection_round = 1.
-- That inspection must contain at least one InspectionResult with
-- result = 'FAIL'.
--
-- Failure definition:
-- Use criterion-level InspectionResult.result, not the inspection-level
-- Inspection.overall_result used by Q01 and Q02.
--
-- Correlation and NULL behavior:
-- EXISTS correlates earlier history to the current equipment_id.
-- Multiple qualifying earlier jobs or failed criteria do not multiply
-- the outer current-job row.
-- A NULL earlier returned_date cannot satisfy the date comparison.
--
-- Output:
-- One row per qualifying currently open job, containing job_id.
-- Sort by job_id ascending.
--
-- Retained clean-seed expectation:
-- 13 qualifying open jobs.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- This is narrower than Q04, which only counts repeated repair jobs.
-- The historical association does not establish that the earlier repair
-- or inspection failure caused the current repair request.

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
