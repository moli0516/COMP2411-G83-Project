-- N15: VERIFIED requires verifying staff
-- Prerequisite: existing negative_setup_sql in the same session.
-- Expected 3819/HY000. @nt is a valid staff FK; role is not tested here.
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date,action_status,resolved_date,resolution_note,verified_by_manager_id,verified_date)
VALUES ('IA missing-field test',@nt,'2026-10-29','2026-10-31','VERIFIED','2026-10-30','Resolution provided',NULL,'2026-10-31');
