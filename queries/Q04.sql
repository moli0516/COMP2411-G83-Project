-- Q04: Equipment received for repair more than once.
-- Management question: MQ02 - Repeat repairs.
-- Techniques: join;join3plus;group_by;having
--
-- Purpose:
-- Identify equipment records associated with multiple received repair jobs.
--
-- Source and population:
-- Join Equipment to RequestItem and then to ServiceJob.
-- Count existing service jobs, not quotation versions, service requests,
-- or request items that have not yet produced a job.
-- Include jobs regardless of their current job_status.
-- No universal reporting-date cutoff is applied.
--
-- Calculation:
-- repair_count counts joined ServiceJob rows for each equipment record.
-- first_received_date and latest_received_date are the minimum and
-- maximum received_date values among those jobs.
-- HAVING COUNT(*) > 1 retains only equipment with multiple repair jobs.
--
-- Output:
-- One row per equipment record with more than one service job.
-- Sort by repair_count descending and equipment_id ascending.
--
-- Retained clean-seed expectation:
-- 14 equipment records: 4 with three jobs and 10 with two jobs.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- Multiple repairs identify equipment histories for further review.
-- The query does not require an earlier failed inspection and does not
-- establish that an earlier repair caused a later repair request.
-- Q08 applies additional historical inspection and current-job conditions.

SELECT
    e.equipment_id,
    e.serial_no,
    COUNT(*) AS repair_count,
    MIN(j.received_date) AS first_received_date,
    MAX(j.received_date) AS latest_received_date
FROM Equipment AS e
JOIN RequestItem AS ri
    ON ri.equipment_id = e.equipment_id
JOIN ServiceJob AS j
    ON j.request_item_id = ri.request_item_id
GROUP BY
    e.equipment_id,
    e.serial_no
HAVING COUNT(*) > 1
ORDER BY
    repair_count DESC,
    e.equipment_id ASC;
