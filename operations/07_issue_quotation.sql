-- Inputs: request_id, quotation_date, quoted_amount
SELECT EXISTS(SELECT 1 FROM ServiceRequest r WHERE r.request_id=%(request_id)s AND r.request_status IN ('PENDING_QUOTATION','QUOTED','SUSPENDED') AND %(quotation_date)s>=r.request_date AND EXISTS(SELECT 1 FROM RequestItem ri WHERE ri.request_id=r.request_id)) AND NOT EXISTS(SELECT 1 FROM Quotation WHERE request_id=%(request_id)s AND (quotation_status='ACCEPTED' OR quotation_date>%(quotation_date)s OR customer_decision_date>%(quotation_date)s)) AND %(quoted_amount)s>0 AS ok;
SELECT COALESCE(MAX(quotation_version),0)+1 INTO @op_version FROM Quotation WHERE request_id=%(request_id)s;
UPDATE Quotation SET quotation_status='REVISED' WHERE request_id=%(request_id)s AND quotation_status='PENDING';
INSERT INTO Quotation(request_id,quotation_version,quoted_amount,quotation_date,quotation_status) VALUES (%(request_id)s,@op_version,%(quoted_amount)s,%(quotation_date)s,'PENDING');
SET @op_quotation_id=LAST_INSERT_ID();
UPDATE ServiceRequest SET request_status='QUOTED' WHERE request_id=%(request_id)s;
SELECT @op_quotation_id AS quotation_id,@op_version AS quotation_version;
