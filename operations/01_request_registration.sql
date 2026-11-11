-- Inputs: customer_id, equipment_id, request_date, fault_description
SELECT EXISTS(SELECT 1 FROM Equipment WHERE equipment_id=%(equipment_id)s AND customer_id=%(customer_id)s) AND CHAR_LENGTH(TRIM(%(fault_description)s))>0 AS ok;
INSERT INTO ServiceRequest(customer_id,request_date,fault_description,request_status) VALUES (%(customer_id)s,%(request_date)s,%(fault_description)s,'PENDING_QUOTATION');
SET @op_request_id=LAST_INSERT_ID();
INSERT INTO RequestItem(request_id,equipment_id,item_status) VALUES (@op_request_id,%(equipment_id)s,'AWAITING_DELIVERY');
SELECT @op_request_id AS request_id, LAST_INSERT_ID() AS request_item_id;
