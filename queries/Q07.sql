-- Q07: Unresolved corrective-action workload by technician.
-- Management question: MQ04 - Technician unresolved-action workload.
-- Techniques: join;group_by;null_handling
--
-- Purpose:
-- Count unresolved corrective actions assigned to each technician,
-- including technicians with no unresolved actions.
--
-- Population:
-- Include Staff rows whose role is TECHNICIAN.
-- No active_status filter is applied, so retained inactive technicians
-- are included as well.
-- No reporting-date cutoff is applied.
--
-- Status definition:
-- Unresolved means action_status IN ('OPEN', 'IN_PROGRESS').
-- RESOLVED and VERIFIED actions are excluded from this workload count.
-- This differs from the broader unverified population in Q03 and Q05.
--
-- LEFT JOIN and NULL handling:
-- Filter action status in the ON clause to preserve technicians with
-- no matching unresolved actions.
-- COUNT(ca.action_id) ignores the NULL-extended unmatched rows and
-- therefore returns zero for technicians without unresolved actions.
-- COUNT(*) would incorrectly count an unmatched technician row as one.
--
-- Output:
-- One row per technician, including active_status.
-- Sort by unresolved_action_count descending and technician_id ascending.
--
-- Retained clean-seed expectation:
-- 9 technicians: 7 with two unresolved actions and 2 with zero.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- Counts describe assignment volume, not action complexity, hours worked,
-- or a complete measure of technician effort or performance.

SELECT
    s.staff_id AS technician_id,
    s.staff_name AS technician_name,
    s.active_status,
    COUNT(ca.action_id) AS unresolved_action_count
FROM Staff AS s
LEFT JOIN CorrectiveAction AS ca
    ON ca.assigned_staff_id = s.staff_id
   AND ca.action_status IN ('OPEN', 'IN_PROGRESS')
WHERE s.role = 'TECHNICIAN'
GROUP BY
    s.staff_id,
    s.staff_name,
    s.active_status
ORDER BY
    unresolved_action_count DESC,
    s.staff_id ASC;