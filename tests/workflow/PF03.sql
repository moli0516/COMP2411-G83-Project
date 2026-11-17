-- PF03: Different eligible inspector completes PASS and makes job ready
-- Fixture only; runner owns transaction and rollback.
INSERT INTO Customer(customer_name,phone) VALUES ('PF synthetic customer','0000000000');
SET @pfc=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('PF technician','TECHNICIAN',1);
SET @pft=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('PF inspector','INSPECTOR',1);
SET @pfi=LAST_INSERT_ID();
INSERT INTO Staff(staff_name,role,active_status) VALUES ('PF manager','MANAGER',1);
SET @pfm=LAST_INSERT_ID();
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories)
VALUES (@pfc,'GPU','TEST','PF-GPU',CONCAT('PF-',UUID()),'Intact','NONE');
SET @pfe1=LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id,request_date,fault_description) VALUES (@pfc,'2026-10-20','PF synthetic repair');
SET @pfr=LAST_INSERT_ID();
INSERT INTO RequestItem(request_id,equipment_id) VALUES (@pfr,@pfe1);
SET @pfitem1=LAST_INSERT_ID();
