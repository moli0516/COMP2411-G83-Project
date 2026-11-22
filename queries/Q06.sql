-- Q06: Medium- or high-severity incidents without corrective-action links.
-- Management question: MQ03 - Corrective-action follow-up and auditing.
-- Techniques: join;subquery;correlated;exists
--
-- Purpose:
-- Audit medium- and high-severity incidents for missing follow-up links.
--
-- Source and population:
-- Join Incident to its ServiceJob.
-- Include incidents with severity MEDIUM or HIGH.
-- No incident-status restriction or reporting-date cutoff is applied.
--
-- Missing-link test:
-- A correlated NOT EXISTS subquery searches IncidentCorrectiveAction
-- for a row with the current incident_id.
-- Retain the incident only when no such linking row exists.
-- The exists technique tag covers the NOT EXISTS predicate used here.
--
-- Output:
-- One row per qualifying incident without a corrective-action link.
-- Sort by incident_date ascending and incident_id ascending.
--
-- Retained clean-seed expectation:
-- Zero data rows.
-- The exported CSV must still contain its column headers.
-- A header-only result is the intended audit outcome, not a query failure.
-- Run before mutation tests or WebUI operations change the seed state.
--
-- Interpretation:
-- This query detects missing links; it does not prevent their creation.
-- An existing link does not prove that its corrective action is adequate,
-- resolved, verified, or appropriate for the incident.
-- A zero-row result does not prove that missing links are impossible.

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