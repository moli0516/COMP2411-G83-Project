-- N09: Duplicate inspection round
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1062, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO Inspection(job_id,inspector_id,inspection_round) VALUES (@nj,@ns,1);
