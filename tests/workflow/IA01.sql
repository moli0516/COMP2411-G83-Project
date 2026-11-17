-- IA01; fixture only. Run via run_sql_tests.py and metadata.
-- Incident/action fixture; runner owns transaction and cleanup.
INSERT INTO Customer(customer_name,phone) VALUES ('IA synthetic customer','0000000000');
SET @ic=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA technician','TECHNICIAN',1);
SET @it=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('IA manager','MANAGER',1);
SET @im=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@ic,'GPU','TEST','IA',CONCAT('IA-',UUID()),'Synthetic intact','NONE');
SET @ie=LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id,request_date,fault_description,request_status)
VALUES (@ic,'2026-10-28','IA fixture','ACCEPTED');
SET @ir=LAST_INSERT_ID();
INSERT INTO RequestItem(request_id,equipment_id,item_status) VALUES (@ir,@ie,'RECEIVED');
SET @ii=LAST_INSERT_ID();
INSERT INTO Quotation(request_id,quotation_version,quoted_amount,quotation_date,quotation_status,customer_decision_date)
VALUES (@ir,1,500,'2026-10-28','ACCEPTED','2026-10-28');
INSERT INTO ServiceJob(request_item_id,technician_id,received_date,job_status)
VALUES (@ii,@it,'2026-10-29','IN_REPAIR');
SET @ij=LAST_INSERT_ID();
UPDATE ServiceRequest SET request_status='IN_PROGRESS' WHERE request_id=@ir;
