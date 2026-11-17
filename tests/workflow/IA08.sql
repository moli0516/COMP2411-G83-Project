-- IA08: two incidents on different jobs share X; first incident also links Y.
START TRANSACTION;
-- Runner owns transaction for workflow mode; SQL mode adds START/ROLLBACK.
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA extra technician','TECHNICIAN',1);
SET @iat=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA extra manager','MANAGER',1);
SET @iam=LAST_INSERT_ID();
INSERT INTO Customer(customer_name,phone) VALUES ('IA shared customer','0000000000');
SET @isc=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@isc,'GPU','TEST','A',CONCAT('IAS-',UUID()),'Intact','NONE');
SET @ise1=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@isc,'RAM','TEST','B',CONCAT('IAS-',UUID()),'Intact','NONE');
SET @ise2=LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id,request_date,fault_description) VALUES (@isc,'2026-10-28','IA shared fixture');
SET @isr=LAST_INSERT_ID();
INSERT INTO RequestItem(request_id,equipment_id) VALUES (@isr,@ise1);
SET @isi1=LAST_INSERT_ID();
INSERT INTO RequestItem(request_id,equipment_id) VALUES (@isr,@ise2);
SET @isi2=LAST_INSERT_ID();
INSERT INTO Quotation(request_id,quotation_version,quoted_amount,quotation_date,quotation_status,customer_decision_date)
VALUES (@isr,1,500,'2026-10-28','ACCEPTED','2026-10-28');
UPDATE ServiceRequest SET request_status='ACCEPTED' WHERE request_id=@isr;
UPDATE RequestItem SET item_status='RECEIVED' WHERE request_id=@isr;
INSERT INTO ServiceJob(request_item_id,technician_id,received_date) VALUES (@isi1,@iat,'2026-10-29');
SET @isj1=LAST_INSERT_ID();
INSERT INTO ServiceJob(request_item_id,technician_id,received_date) VALUES (@isi2,@iat,'2026-10-29');
SET @isj2=LAST_INSERT_ID();
UPDATE ServiceRequest SET request_status='IN_PROGRESS' WHERE request_id=@isr;
INSERT INTO Incident(job_id,reported_by_staff_id,incident_date,incident_type,severity,incident_description)
VALUES (@isj1,@iat,'2026-10-30','QUALITY','HIGH','IA incident A');
SET @isa=LAST_INSERT_ID();
INSERT INTO Incident(job_id,reported_by_staff_id,incident_date,incident_type,severity,incident_description)
VALUES (@isj2,@iat,'2026-10-30','QUALITY','MEDIUM','IA incident B');
SET @isb=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date)
VALUES ('IA shared action X',@iat,'2026-10-30','2026-10-31');
SET @isx=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date)
VALUES ('IA additional action Y',@iat,'2026-10-30','2026-10-31');
SET @isy=LAST_INSERT_ID();
INSERT INTO IncidentCorrectiveAction(incident_id,action_id) VALUES (@isa,@isx),(@isb,@isx),(@isa,@isy);
SELECT 'IA08_LINKS' AS test_id,i.job_id,l.incident_id,l.action_id
FROM IncidentCorrectiveAction l JOIN Incident i ON i.incident_id=l.incident_id
WHERE l.incident_id IN (@isa,@isb) ORDER BY l.incident_id,l.action_id;
SELECT ((SELECT COUNT(*) FROM IncidentCorrectiveAction WHERE incident_id IN (@isa,@isb))=3
 AND (SELECT COUNT(*) FROM IncidentCorrectiveAction WHERE action_id=@isx)=2
 AND (SELECT COUNT(*) FROM IncidentCorrectiveAction WHERE incident_id=@isa)=2
 AND @isj1<>@isj2) INTO @is_ok;
ROLLBACK;
SELECT 'IA08' AS test_id,IF(@is_ok=1
 AND NOT EXISTS(SELECT 1 FROM IncidentCorrectiveAction WHERE incident_id IN (@isa,@isb))
 AND NOT EXISTS(SELECT 1 FROM Incident WHERE incident_id IN (@isa,@isb))
 AND NOT EXISTS(SELECT 1 FROM CorrectiveAction WHERE action_id IN (@isx,@isy))
 AND NOT EXISTS(SELECT 1 FROM ServiceJob WHERE job_id IN (@isj1,@isj2))
 AND NOT EXISTS(SELECT 1 FROM RequestItem WHERE request_item_id IN (@isi1,@isi2))
 AND NOT EXISTS(SELECT 1 FROM Quotation WHERE request_id=@isr)
 AND NOT EXISTS(SELECT 1 FROM ServiceRequest WHERE request_id=@isr)
 AND NOT EXISTS(SELECT 1 FROM Equipment WHERE equipment_id IN (@ise1,@ise2))
 AND NOT EXISTS(SELECT 1 FROM Customer WHERE customer_id=@isc)
 AND NOT EXISTS(SELECT 1 FROM Staff WHERE staff_id IN (@iat,@iam)),'PASS','FAIL') AS result;
