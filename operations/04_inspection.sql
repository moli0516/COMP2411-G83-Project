-- Inputs: job_id, inspector_id, inspection_date, criterion_name, result, remarks
-- Creates one completed inspection with one meaningful criterion.
SELECT EXISTS(SELECT 1 FROM ServiceJob WHERE job_id=%(job_id)s AND job_status='SUBMITTED_FOR_INSPECTION' AND repair_completed_date IS NOT NULL AND repair_description IS NOT NULL AND %(inspection_date)s>=repair_completed_date AND technician_id<>%(inspector_id)s) AND EXISTS(SELECT 1 FROM Staff WHERE staff_id=%(inspector_id)s AND role='INSPECTOR' AND active_status=1) AND %(result)s IN ('PASS','FAIL') AND NOT EXISTS(SELECT 1 FROM Inspection WHERE job_id=%(job_id)s AND inspection_status='IN_PROGRESS') AND NOT EXISTS(SELECT 1 FROM Inspection WHERE job_id=%(job_id)s AND inspection_date>%(inspection_date)s) AS ok;
SELECT COALESCE(MAX(inspection_round),0)+1 INTO @op_round FROM Inspection WHERE job_id=%(job_id)s;
INSERT INTO Inspection(job_id,inspector_id,inspection_round,inspection_status) VALUES (%(job_id)s,%(inspector_id)s,@op_round,'IN_PROGRESS');
SET @op_inspection_id=LAST_INSERT_ID();
INSERT INTO InspectionResult(inspection_id,criterion_name,result,remarks) VALUES (@op_inspection_id,%(criterion_name)s,%(result)s,%(remarks)s);
UPDATE Inspection SET inspection_status='COMPLETED',inspection_date=%(inspection_date)s,overall_result=%(result)s WHERE inspection_id=@op_inspection_id;
UPDATE ServiceJob SET job_status=CASE WHEN %(result)s='FAIL' THEN 'REWORK_REQUIRED' ELSE 'READY_FOR_RETURN' END WHERE job_id=%(job_id)s;
SELECT @op_inspection_id AS inspection_id,@op_round AS inspection_round;
