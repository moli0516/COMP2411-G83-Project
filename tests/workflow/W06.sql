-- W06: Reject action verification by a non-manager
-- Fixture only; executed inside runner transaction. Do not run alone as evidence.
-- Transactional synthetic fixture. No COMMIT; runner owns rollback.
INSERT INTO Customer(customer_name,phone) VALUES ('WF owner','0000000000');
SET @wc=LAST_INSERT_ID();
INSERT INTO Customer(customer_name,phone) VALUES ('WF other owner','0000000001');
SET @wo=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role) VALUES ('WF technician','TECHNICIAN');
SET @wt=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role) VALUES ('WF inspector','INSPECTOR');
SET @ws=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role) VALUES ('WF manager','MANAGER');
SET @wm=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@wc,'GPU','TEST','WF',CONCAT('WF-',UUID()),'Intact','NONE');
SET @we=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@wo,'GPU','TEST','WF-other',CONCAT('WF-',UUID()),'Intact','NONE');
SET @we_other=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@wc,'RAM','TEST','WF-extra',CONCAT('WF-',UUID()),'Intact','NONE');
SET @we_extra=LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id,request_date,fault_description)
VALUES (@wc,'2026-10-29','WF synthetic repair');
SET @wr=LAST_INSERT_ID();
INSERT INTO RequestItem(request_id,equipment_id) VALUES (@wr,@we);
SET @wi=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date,action_status,resolved_date,resolution_note) VALUES ('WF action',@wt,'2026-10-29','2026-10-31','RESOLVED','2026-10-30','Synthetic resolution');
SET @wa=LAST_INSERT_ID();
