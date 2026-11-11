-- W07: Return eligible job but retain open request with undelivered item
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
INSERT INTO RequestItem(request_id,equipment_id) VALUES (@wr,@we_extra);
INSERT INTO Quotation(request_id,quotation_version,quoted_amount,quotation_date,quotation_status,customer_decision_date)
VALUES (@wr,1,500,'2026-10-29','ACCEPTED','2026-10-29');
UPDATE ServiceRequest SET request_status='ACCEPTED' WHERE request_id=@wr;
UPDATE RequestItem SET item_status='RECEIVED' WHERE request_item_id=@wi;
INSERT INTO ServiceJob(request_item_id,technician_id,received_date,job_status,repair_description,repair_completed_date)
VALUES (@wi,@wt,'2026-10-30','SUBMITTED_FOR_INSPECTION','Synthetic repair','2026-10-30');
SET @wj=LAST_INSERT_ID();
UPDATE ServiceRequest SET request_status='IN_PROGRESS' WHERE request_id=@wr;
INSERT INTO Inspection(job_id,inspector_id,inspection_round,inspection_status,inspection_date,overall_result)
VALUES (@wj,@ws,1,'COMPLETED','2026-10-30','PASS');
SET @wx=LAST_INSERT_ID();
INSERT INTO InspectionResult(inspection_id,criterion_name,result) VALUES (@wx,'POWER_ON','PASS');
UPDATE ServiceJob SET job_status='READY_FOR_RETURN' WHERE job_id=@wj;
