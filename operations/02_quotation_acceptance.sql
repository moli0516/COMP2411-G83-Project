-- Inputs: quotation_id, decision_date
SELECT EXISTS(SELECT 1 FROM Quotation q JOIN ServiceRequest r ON r.request_id=q.request_id WHERE q.quotation_id=%(quotation_id)s AND q.quotation_status='PENDING' AND r.request_status='QUOTED' AND %(decision_date)s>=q.quotation_date AND NOT EXISTS(SELECT 1 FROM Quotation x WHERE x.request_id=q.request_id AND x.quotation_status='ACCEPTED') AND EXISTS(SELECT 1 FROM RequestItem ri WHERE ri.request_id=q.request_id)) AS ok;
UPDATE Quotation SET quotation_status='ACCEPTED',customer_decision_date=%(decision_date)s WHERE quotation_id=%(quotation_id)s;
UPDATE ServiceRequest r JOIN Quotation q ON q.request_id=r.request_id SET r.request_status='ACCEPTED' WHERE q.quotation_id=%(quotation_id)s;
SELECT quotation_id,request_id,quotation_status FROM Quotation WHERE quotation_id=%(quotation_id)s;
