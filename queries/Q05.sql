-- Q05: Overdue unverified actions exceeding the average overdue duration.
-- Management question: MQ03 - Corrective-action follow-up.
-- Techniques: subquery
--
-- Purpose:
-- Identify overdue unverified corrective actions whose overdue duration
-- is strictly greater than the average for the same population.
--
-- Reporting reference date:
-- 2026-10-31.
-- Both the outer query and the scalar subquery require:
--   due_date < '2026-10-31'
--   AND action_status <> 'VERIFIED'.
-- Actions due on the reference date are not overdue.
-- RESOLVED actions awaiting verification remain included.
--
-- Calculation:
-- days_overdue = DATEDIFF('2026-10-31', due_date).
-- The non-correlated scalar subquery calculates AVG(days_overdue)
-- across all overdue unverified actions.
-- The outer query retains actions strictly above that average;
-- actions equal to the average are excluded.
--
-- Output:
-- One row per qualifying corrective action.
-- Sort by days_overdue descending and action_id ascending.
-- The population average is used for filtering but is not an output column.
--
-- Retained clean-seed expectation:
-- The 10-action comparison population has an average of 11 overdue days.
-- 5 actions, action_id 21 through 25, exceed that average.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- The average is a descriptive comparison, not an approved service target.
-- Overdue duration alone does not establish severity, cause of delay,
-- or technician performance.

SELECT
    a.action_id,
    a.action_status,
    a.due_date,
    DATEDIFF('2026-10-31', a.due_date) AS days_overdue
FROM CorrectiveAction AS a
WHERE a.action_status <> 'VERIFIED'
    AND a.due_date < '2026-10-31'
    AND DATEDIFF('2026-10-31', a.due_date) > (
        SELECT
            AVG(DATEDIFF('2026-10-31', b.due_date))
        FROM CorrectiveAction AS b
        WHERE b.action_status <> 'VERIFIED'
            AND b.due_date < '2026-10-31'
    )
ORDER BY days_overdue DESC, a.action_id;