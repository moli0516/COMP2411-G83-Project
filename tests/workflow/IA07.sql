-- IA07: legal NULL state combinations (constraint-level test).
START TRANSACTION;
-- Runner owns transaction for workflow mode; SQL mode adds START/ROLLBACK.
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA extra technician','TECHNICIAN',1);
SET @iat=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA extra manager','MANAGER',1);
SET @iam=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date,action_status)
VALUES ('IA valid OPEN',@iat,'2026-10-29','2026-10-31','OPEN');
SET @iao=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date,action_status,resolved_date,resolution_note)
VALUES ('IA valid RESOLVED',@iat,'2026-10-29','2026-10-31','RESOLVED','2026-10-30','Complete');
SET @iar=LAST_INSERT_ID();
SELECT (COUNT(*)=2) INTO @ia_legal_ok FROM CorrectiveAction
WHERE (action_id=@iao AND action_status='OPEN' AND resolved_date IS NULL AND resolution_note IS NULL AND verified_by_manager_id IS NULL AND verified_date IS NULL)
   OR (action_id=@iar AND action_status='RESOLVED' AND resolved_date='2026-10-30' AND resolution_note='Complete' AND verified_by_manager_id IS NULL AND verified_date IS NULL);
SELECT 'IA07_BEFORE_ROLLBACK' AS test_id,action_id,action_status,resolved_date,resolution_note,verified_by_manager_id,verified_date
FROM CorrectiveAction WHERE action_id IN (@iao,@iar) ORDER BY action_id;
ROLLBACK;
SELECT 'IA07' AS test_id,IF(@ia_legal_ok=1
 AND NOT EXISTS(SELECT 1 FROM CorrectiveAction WHERE action_id IN (@iao,@iar))
 AND NOT EXISTS(SELECT 1 FROM Staff WHERE staff_id IN (@iat,@iam)),'PASS','FAIL') AS result;
