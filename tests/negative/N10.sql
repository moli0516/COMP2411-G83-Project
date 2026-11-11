-- N10: Duplicate inspection criterion
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1062, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO InspectionResult(inspection_id,criterion_name,result) VALUES (@nx,'POWER_ON','PASS');
