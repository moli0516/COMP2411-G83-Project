-- Q03: Overdue unverified corrective actions at a fixed reporting date.
-- Management question: MQ03 - Corrective-action follow-up.
-- Techniques: view
--
-- Purpose:
-- List corrective actions whose due dates have passed but which have
-- not yet reached VERIFIED status.
--
-- Source:
-- vw_corrective_action_followup provides action and assigned-staff details.
-- Joins are encapsulated by the view rather than written in this SELECT.
--
-- Reporting reference date:
-- 2026-10-31.
-- An action is overdue only when due_date < '2026-10-31'.
-- Actions due on the reference date are not yet overdue.
--
-- Status definition:
-- Unverified means action_status <> 'VERIFIED'.
-- This includes OPEN, IN_PROGRESS, and RESOLVED actions.
-- RESOLVED actions remain included until verification is completed.
--
-- Calculation:
-- days_overdue = DATEDIFF('2026-10-31', due_date).
-- This measures days since the due date, not days since resolution.
--
-- Output:
-- One row per qualifying corrective action.
-- This SELECT has no ORDER BY; output row order is not guaranteed.
-- Compare exported results by row contents rather than display order.
--
-- Retained clean-seed expectation:
-- 10 actions: 8 RESOLVED and 2 IN_PROGRESS.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- Distinguish unfinished corrective work from completed work awaiting
-- verification; both may appear in this unverified backlog.

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

