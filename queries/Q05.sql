-- Q05: Corrective actions overdue longer than average
-- Reporting date: 2026-10-31

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