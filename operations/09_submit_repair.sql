-- Inputs: job_id, repair_completed_date, repair_description
SELECT EXISTS(SELECT 1 FROM ServiceJob WHERE job_id=%(job_id)s AND job_status IN ('RECEIVED','IN_REPAIR','REWORK_REQUIRED') AND %(repair_completed_date)s>=received_date) AND CHAR_LENGTH(TRIM(%(repair_description)s))>0 AND NOT EXISTS(SELECT 1 FROM Inspection WHERE job_id=%(job_id)s AND (inspection_status='IN_PROGRESS' OR inspection_date>%(repair_completed_date)s)) AS ok;
UPDATE ServiceJob SET repair_description=%(repair_description)s,repair_completed_date=%(repair_completed_date)s,job_status='SUBMITTED_FOR_INSPECTION' WHERE job_id=%(job_id)s;
SELECT job_id,job_status,repair_completed_date FROM ServiceJob WHERE job_id=%(job_id)s;
