-- Inputs: request_id, equipment_id
SELECT EXISTS(SELECT 1 FROM ServiceRequest r JOIN Equipment e ON e.customer_id=r.customer_id WHERE r.request_id=%(request_id)s AND e.equipment_id=%(equipment_id)s AND r.request_status='PENDING_QUOTATION' AND NOT EXISTS(SELECT 1 FROM Quotation q WHERE q.request_id=r.request_id)) AS ok;
INSERT INTO RequestItem(request_id,equipment_id,item_status) VALUES (%(request_id)s,%(equipment_id)s,'AWAITING_DELIVERY');
SELECT LAST_INSERT_ID() AS request_item_id;
