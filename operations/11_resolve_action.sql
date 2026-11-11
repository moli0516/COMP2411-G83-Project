-- Inputs: action_id, resolved_date, resolution_note
SELECT EXISTS(SELECT 1 FROM CorrectiveAction WHERE action_id=%(action_id)s AND action_status IN ('OPEN','IN_PROGRESS') AND %(resolved_date)s>=created_date) AND CHAR_LENGTH(TRIM(%(resolution_note)s))>0 AS ok;
UPDATE CorrectiveAction SET action_status='RESOLVED',resolved_date=%(resolved_date)s,resolution_note=%(resolution_note)s,verified_by_manager_id=NULL,verified_date=NULL WHERE action_id=%(action_id)s;
SELECT action_id,action_status,resolved_date FROM CorrectiveAction WHERE action_id=%(action_id)s;
