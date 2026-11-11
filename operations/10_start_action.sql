-- Inputs: action_id
SELECT EXISTS(SELECT 1 FROM CorrectiveAction WHERE action_id=%(action_id)s AND action_status='OPEN') AS ok;
UPDATE CorrectiveAction SET action_status='IN_PROGRESS' WHERE action_id=%(action_id)s;
SELECT action_id,action_status FROM CorrectiveAction WHERE action_id=%(action_id)s;
