-- BD10: Negative quotation amount rejected by operation validation
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
UPDATE Quotation SET quotation_status='REVISED',customer_decision_date=NULL WHERE quotation_id=@btq;
UPDATE ServiceRequest SET request_status='QUOTED' WHERE request_id=@btr;
