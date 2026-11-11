-- Inputs: request_item_id, technician_id, received_date
SELECT EXISTS(SELECT 1 FROM RequestItem ri JOIN ServiceRequest r ON r.request_id=ri.request_id JOIN Equipment e ON e.equipment_id=ri.equipment_id WHERE ri.request_item_id=%(request_item_id)s AND ri.item_status='AWAITING_DELIVERY' AND r.request_status IN ('ACCEPTED','IN_PROGRESS') AND e.customer_id=r.customer_id AND %(received_date)s>=r.request_date AND EXISTS(SELECT 1 FROM Quotation q WHERE q.request_id=r.request_id AND q.quotation_status='ACCEPTED' AND q.customer_decision_date<=%(received_date)s) AND NOT EXISTS(SELECT 1 FROM ServiceJob j WHERE j.request_item_id=ri.request_item_id)) AND EXISTS(SELECT 1 FROM Staff WHERE staff_id=%(technician_id)s AND role='TECHNICIAN' AND active_status=1) AS ok;
UPDATE RequestItem SET item_status='RECEIVED' WHERE request_item_id=%(request_item_id)s;
INSERT INTO ServiceJob(request_item_id,technician_id,received_date,job_status) VALUES (%(request_item_id)s,%(technician_id)s,%(received_date)s,'RECEIVED');
SET @op_job_id=LAST_INSERT_ID();
UPDATE ServiceRequest r JOIN RequestItem ri ON ri.request_id=r.request_id SET r.request_status='IN_PROGRESS' WHERE ri.request_item_id=%(request_item_id)s;
SELECT @op_job_id AS job_id;
