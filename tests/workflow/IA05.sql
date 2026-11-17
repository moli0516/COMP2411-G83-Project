-- IA05: Reject verification of IN_PROGRESS action
-- Runner owns transaction for workflow mode; SQL mode adds START/ROLLBACK.
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA extra technician','TECHNICIAN',1);
SET @iat=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA extra manager','MANAGER',1);
SET @iam=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date,action_status) VALUES ('IA transition fixture',@iat,'2026-10-29','2026-10-31','IN_PROGRESS');
SET @iaa=LAST_INSERT_ID();
