-- transaction_rollback.sql | TXR01 | duplicate receipt failure
-- INTERACTIVE EXECUTION REQUIRED: execute the labelled blocks separately
-- in the SAME connection. Do not reconnect between failure and ROLLBACK.
-- Do not use client error handling that automatically rolls back the test.
-- If the client stops on the expected error, manually execute BLOCK C.
-- Fixture setup is committed; the assessed mutations must be rolled back.
-- No DDL. Export baseline CSVs before running mutation tests.

-- BLOCK A: setup and before-state.
SELECT DATABASE() AS database_name, @@autocommit AS autocommit_setting;
-- SETUP BLOCK: deliberately committed fixture, outside the assessed transaction.
-- Unique synthetic serial makes this fixture independent of seed IDs.
START TRANSACTION;
INSERT INTO Customer(customer_name, phone)
VALUES ('txr synthetic customer', '0000000000');
SET @txr_customer = LAST_INSERT_ID();
INSERT INTO Staff(staff_name, role, active_status)
VALUES ('txr synthetic technician', 'TECHNICIAN', TRUE);
SET @txr_technician = LAST_INSERT_ID();
INSERT INTO Equipment(customer_id, component_type, brand, model,
                      serial_no, physical_condition, accessories)
VALUES (@txr_customer, 'GPU', 'TEST', 'TX-MODEL',
        CONCAT('txr-', UUID()), 'Synthetic intact condition', 'NONE');
SET @txr_equipment = LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id, request_date, fault_description, request_status)
VALUES (@txr_customer, '2026-10-30', 'txr synthetic repair', 'ACCEPTED');
SET @txr_request = LAST_INSERT_ID();
INSERT INTO RequestItem(request_id, equipment_id, item_status)
VALUES (@txr_request, @txr_equipment, 'AWAITING_DELIVERY');
SET @txr_item = LAST_INSERT_ID();
INSERT INTO Quotation(request_id, quotation_version, quoted_amount,
                      quotation_date, quotation_status, customer_decision_date)
VALUES (@txr_request, 1, 500.00, '2026-10-30', 'ACCEPTED', '2026-10-30');
COMMIT;
SELECT 'TXR01_BEFORE' AS test_id, r.request_id, r.request_status,
       ri.request_item_id, ri.item_status, j.job_id, j.job_status
FROM ServiceRequest r
JOIN RequestItem ri ON ri.request_id = r.request_id
LEFT JOIN ServiceJob j ON j.request_item_id = ri.request_item_id
WHERE ri.request_item_id = @txr_item;

-- BLOCK B1: successful related changes inside the assessed transaction.
START TRANSACTION;
UPDATE RequestItem SET item_status = 'RECEIVED'
WHERE request_item_id = @txr_item AND item_status = 'AWAITING_DELIVERY';
INSERT INTO ServiceJob(request_item_id, technician_id, received_date, job_status)
VALUES (@txr_item, @txr_technician, '2026-10-31', 'RECEIVED');
UPDATE ServiceRequest SET request_status = 'IN_PROGRESS'
WHERE request_id = @txr_request AND request_status = 'ACCEPTED';
SELECT 'TXR01_INTERMEDIATE' AS test_id, r.request_id, r.request_status,
       ri.request_item_id, ri.item_status, j.job_id, j.job_status
FROM ServiceRequest r
JOIN RequestItem ri ON ri.request_id = r.request_id
LEFT JOIN ServiceJob j ON j.request_item_id = ri.request_item_id
WHERE ri.request_item_id = @txr_item;

-- BLOCK B2: execute this ONE statement; expected MySQL error 1062,
-- SQLSTATE 23000: duplicate UNIQUE ServiceJob.request_item_id.
-- Simulates a duplicate job creation during receipt processing.
INSERT INTO ServiceJob(request_item_id, technician_id, received_date, job_status)
VALUES (@txr_item, @txr_technician, '2026-10-31', 'RECEIVED');

-- BLOCK C: AFTER the expected error, execute this block manually if needed.
-- The error alone does not demonstrate rollback of earlier statements.
ROLLBACK;
SELECT 'TXR01_AFTER' AS test_id, r.request_id, r.request_status,
       ri.request_item_id, ri.item_status, j.job_id, j.job_status
FROM ServiceRequest r
JOIN RequestItem ri ON ri.request_id = r.request_id
LEFT JOIN ServiceJob j ON j.request_item_id = ri.request_item_id
WHERE ri.request_item_id = @txr_item;

SELECT 'TXR01' AS test_id,
       IF((SELECT item_status FROM RequestItem
           WHERE request_item_id = @txr_item) = 'AWAITING_DELIVERY'
          AND (SELECT request_status FROM ServiceRequest
               WHERE request_id = @txr_request) = 'ACCEPTED'
          AND (SELECT COUNT(*) FROM ServiceJob
               WHERE request_item_id = @txr_item) = 0,
          'PASS', 'FAIL') AS result,
       (SELECT COUNT(*) FROM ServiceJob
        WHERE request_item_id = @txr_item) AS remaining_jobs;
-- Expected: PASS, remaining_jobs=0; before and after states match.
-- Committed fixture records remain intentionally. Rebuild to restore seed.
