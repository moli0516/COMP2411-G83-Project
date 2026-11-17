-- Q06: Medium/high incidents missing a corrective-action link.
-- Correlated NOT EXISTS audits the follow-up requirement.
-- Expected clean-seed result: zero rows.
-- This query detects missing links; it does not prevent them.

SELECT
    i.incident_id,
    j.job_id,
    i.severity,
    i.incident_date
FROM Incident AS i
JOIN ServiceJob AS j
    ON j.job_id = i.job_id
WHERE i.severity IN ('MEDIUM', 'HIGH')
  AND NOT EXISTS (
      SELECT 1
      FROM IncidentCorrectiveAction AS ica
      WHERE ica.incident_id = i.incident_id
  )
ORDER BY
    i.incident_date ASC,
    i.incident_id ASC;