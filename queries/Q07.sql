-- Q07: Unresolved corrective-action workload by technician.
-- Unresolved means OPEN or IN_PROGRESS; RESOLVED is excluded.
-- Filter action status in ON to retain zero-action technicians.
-- COUNT(action_id) returns zero for unmatched LEFT JOIN rows.

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