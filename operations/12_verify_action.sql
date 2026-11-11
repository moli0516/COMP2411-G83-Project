-- Inputs: action_id, manager_id, verified_date
SELECT EXISTS(SELECT 1 FROM CorrectiveAction WHERE action_id=%(action_id)s AND action_status='RESOLVED' AND resolved_date IS NOT NULL AND %(verified_date)s>=resolved_date) AND EXISTS(SELECT 1 FROM Staff WHERE staff_id=%(manager_id)s AND role='MANAGER' AND active_status=1) AS ok;
UPDATE CorrectiveAction SET action_status='VERIFIED',verified_by_manager_id=%(manager_id)s,verified_date=%(verified_date)s WHERE action_id=%(action_id)s;
SELECT action_id,action_status,verified_by_manager_id,verified_date FROM CorrectiveAction WHERE action_id=%(action_id)s;
