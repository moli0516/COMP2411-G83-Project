-- 03_views.sql
-- Purpose: provide corrective-action follow-up information.
-- Row meaning: exactly one row per corrective action.
-- Manager details remain NULL until a verifying manager is recorded.
-- Reporting-date filters belong in queries, not in this view.
-- Intended for reporting; use controlled operations for workflow updates.

CREATE VIEW vw_corrective_action_followup AS
SELECT
    ca.action_id,
    ca.action_description,
    ca.assigned_staff_id,
    assignee.staff_name AS assigned_staff_name,
    assignee.role AS assigned_staff_role,
    assignee.active_status AS assigned_staff_active_status,
    ca.created_date,
    ca.due_date,
    ca.action_status,
    ca.resolved_date,
    ca.resolution_note,
    ca.verified_by_manager_id,
    verifier.staff_name AS verifying_manager_name,
    ca.verified_date
FROM CorrectiveAction AS ca
INNER JOIN Staff AS assignee
    ON assignee.staff_id = ca.assigned_staff_id
LEFT JOIN Staff AS verifier
    ON verifier.staff_id = ca.verified_by_manager_id;

-- View: vw_first_round_inspection
-- Purpose: support first-round inspection analysis by component type
--          and responsible technician.
-- Row meaning: one row per service job with a COMPLETED round-1 inspection.
-- Criterion-level results are deliberately excluded to avoid duplicating jobs.

CREATE VIEW vw_first_round_inspection AS
SELECT
    sj.job_id,
    sj.request_item_id,
    ri.request_id,
    e.equipment_id,
    e.serial_no,
    e.component_type,
    e.brand,
    e.model,
    sj.technician_id,
    technician.staff_name AS technician_name,
    sj.received_date,
    i.inspection_id,
    i.inspection_round,
    i.inspection_date,
    i.overall_result,
    i.inspector_id,
    inspector.staff_name AS inspector_name
FROM ServiceJob AS sj
INNER JOIN RequestItem AS ri
    ON ri.request_item_id = sj.request_item_id
INNER JOIN Equipment AS e
    ON e.equipment_id = ri.equipment_id
INNER JOIN Staff AS technician
    ON technician.staff_id = sj.technician_id
INNER JOIN Inspection AS i
    ON i.job_id = sj.job_id
INNER JOIN Staff AS inspector
    ON inspector.staff_id = i.inspector_id
WHERE i.inspection_round = 1
  AND i.inspection_status = 'COMPLETED';

-- View: vw_equipment_repair_history
-- Purpose: support received-repair history and repeat-repair analysis.
-- Row meaning: one row per service job.
-- Equipment without jobs and undelivered request items are excluded.
-- Customer fields identify the requesting customer.
-- Return information remains NULL until recorded.

CREATE VIEW vw_equipment_repair_history AS
SELECT
    sj.job_id,
    ri.request_item_id,
    sr.request_id,
    sr.request_date,
    sr.request_status,
    sr.customer_id AS requesting_customer_id,
    customer.customer_name AS requesting_customer_name,
    e.equipment_id,
    e.serial_no,
    e.component_type,
    e.brand,
    e.model,
    sj.technician_id,
    technician.staff_name AS technician_name,
    sj.received_date,
    sj.job_status,
    sj.repair_description,
    sj.repair_completed_date,
    sj.returned_date,
    sj.returned_by_staff_id,
    returning_staff.staff_name AS returned_by_staff_name
FROM ServiceJob AS sj
INNER JOIN RequestItem AS ri
    ON ri.request_item_id = sj.request_item_id
INNER JOIN ServiceRequest AS sr
    ON sr.request_id = ri.request_id
INNER JOIN Customer AS customer
    ON customer.customer_id = sr.customer_id
INNER JOIN Equipment AS e
    ON e.equipment_id = ri.equipment_id
INNER JOIN Staff AS technician
    ON technician.staff_id = sj.technician_id
LEFT JOIN Staff AS returning_staff
    ON returning_staff.staff_id = sj.returned_by_staff_id;