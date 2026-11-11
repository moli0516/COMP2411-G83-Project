-- N08: At most one job per request item
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1062, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO ServiceJob(request_item_id,technician_id,received_date) VALUES (@ni,@nt,'2026-10-31');
