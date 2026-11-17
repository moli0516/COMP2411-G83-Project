-- BT01: Negative quotation amount rejected
START TRANSACTION;
INSERT INTO Customer(customer_name,phone) VALUES ('BT customer','0000000000');
SET @btc=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('BT technician','TECHNICIAN',1);
SET @btt=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('BT inspector','INSPECTOR',1);
SET @bti=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('BT manager','MANAGER',1);
SET @btm=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@btc,'GPU','TEST','BT',CONCAT('BT-',UUID()),'Intact','NONE');
SET @bte=LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id,request_date,fault_description,request_status)
VALUES (@btc,'2026-10-20','BT fault','ACCEPTED');
SET @btr=LAST_INSERT_ID();
INSERT INTO RequestItem(request_id,equipment_id) VALUES (@btr,@bte);
SET @btri=LAST_INSERT_ID();
INSERT INTO Quotation(request_id,quotation_version,quoted_amount,quotation_date,quotation_status,customer_decision_date)
VALUES (@btr,1,500.00,'2026-10-20','ACCEPTED','2026-10-21');
SET @btq=LAST_INSERT_ID();
INSERT INTO ServiceJob(request_item_id,technician_id,received_date,job_status,repair_description,repair_completed_date)
VALUES (@btri,@btt,'2026-10-21','SUBMITTED_FOR_INSPECTION','BT repair','2026-10-23');
SET @btj=LAST_INSERT_ID();
UPDATE RequestItem SET item_status='RECEIVED' WHERE request_item_id=@btri;
UPDATE ServiceRequest SET request_status='IN_PROGRESS' WHERE request_id=@btr;
INSERT INTO Inspection(job_id,inspector_id,inspection_round,inspection_status)
VALUES (@btj,@bti,1,'IN_PROGRESS');
SET @btins=LAST_INSERT_ID();
INSERT INTO InspectionResult(inspection_id,criterion_name,result) VALUES (@btins,'FUNCTION_TEST','PASS');
INSERT INTO Incident(job_id,reported_by_staff_id,incident_date,incident_type,severity,incident_description)
VALUES (@btj,@btt,'2026-10-23','QUALITY','HIGH','BT incident');
SET @btinc=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date,action_status,resolved_date,resolution_note)
VALUES ('BT action',@btt,'2026-10-23','2026-10-24','RESOLVED','2026-10-24','BT resolution');
SET @bta=LAST_INSERT_ID();
INSERT INTO IncidentCorrectiveAction(incident_id,action_id) VALUES (@btinc,@bta);
SET @btold=(SELECT quoted_amount FROM Quotation WHERE quotation_id=@btq);
UPDATE Quotation SET quoted_amount=-0.01 WHERE quotation_id=@btq;
SET @btok=((SELECT quoted_amount FROM Quotation WHERE quotation_id=@btq) <=> @btold);
ROLLBACK;
SELECT 'BT01' AS test_id,IF(@btok=1 AND NOT EXISTS(SELECT 1 FROM Customer WHERE customer_id=@btc) AND NOT EXISTS(SELECT 1 FROM Staff WHERE staff_id IN (@btt,@bti,@btm)),'PASS','FAIL') AS result;
