-- Inputs: job_id, reporter_id, incident_date, incident_type, severity, incident_description, assigned_staff_id, action_description, due_date
-- This operation always creates an action, including for LOW incidents.
SELECT EXISTS(SELECT 1 FROM ServiceJob WHERE job_id=%(job_id)s AND job_status<>'CLOSED' AND %(incident_date)s>=received_date) AND EXISTS(SELECT 1 FROM Staff WHERE staff_id=%(reporter_id)s AND active_status=1) AND EXISTS(SELECT 1 FROM Staff WHERE staff_id=%(assigned_staff_id)s AND active_status=1) AND %(due_date)s>=%(incident_date)s AS ok;
INSERT INTO Incident(job_id,reported_by_staff_id,incident_date,incident_type,severity,incident_description,incident_status) VALUES (%(job_id)s,%(reporter_id)s,%(incident_date)s,%(incident_type)s,%(severity)s,%(incident_description)s,'OPEN');
SET @op_incident_id=LAST_INSERT_ID();
INSERT INTO CorrectiveAction(action_description,assigned_staff_id,created_date,due_date,action_status) VALUES (%(action_description)s,%(assigned_staff_id)s,%(incident_date)s,%(due_date)s,'OPEN');
SET @op_action_id=LAST_INSERT_ID();
INSERT INTO IncidentCorrectiveAction(incident_id,action_id) VALUES (@op_incident_id,@op_action_id);
SELECT @op_incident_id AS incident_id,@op_action_id AS action_id;
