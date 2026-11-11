-- N05: Duplicate equipment within request
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1062, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO RequestItem(request_id,equipment_id) VALUES (@nr,@ne);
