-- N12: Corrective action due date cannot precede creation
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 3819, SQLSTATE HY000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date) VALUES ('NEG action',@nt,'2026-10-31','2026-10-30');
