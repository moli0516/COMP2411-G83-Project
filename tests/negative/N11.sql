-- N11: Invalid inspection result domain
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 3819, SQLSTATE HY000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO InspectionResult(inspection_id,criterion_name,result) VALUES (@nx,'FUNCTION_TEST','UNKNOWN');
