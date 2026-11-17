-- N17: reject duplicate incident/action composite primary key.
-- Prerequisites: standard seed has at least one IncidentCorrectiveAction row.
-- Existing negative_setup_sql runs in the same transaction before this statement.
-- Expected 1062/23000; runner verifies full table snapshots unchanged.
INSERT INTO IncidentCorrectiveAction(incident_id,action_id)
SELECT incident_id,action_id FROM IncidentCorrectiveAction
ORDER BY incident_id,action_id LIMIT 1;
