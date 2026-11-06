-- Q03: Overdue unverified corrective actions at a fixed reporting date
-- Mapping: MQ03
-- Proposed techniques: join
-- INCOMPLETE: no SELECT implementation.
-- TODO: fixed parameters, row meaning, null behavior and expected result.
-- TODO: author one business SELECT; add ORDER BY if order matters.
SELECT 
    action_id,
    assigned_staff_id,
    assigned_staff_name,
    action_status,
    due_date,
    DATEDIFF("2026-10-31", due_date) as days_overdue
FROM vw_corrective_action_followup
WHERE due_date < "2026-10-31" 
    AND action_status <> "VERIFIED";

