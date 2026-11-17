-- transaction_commit.sql | TXC01 | hardware receipt
-- Use a disposable DB, fresh seed or the exact committed setup below.
-- Same connection; no active transaction. Stop/ROLLBACK on unexpected errors.
-- Fixture remains for evidence. Export baseline query CSVs BEFORE this test.
SELECT DATABASE() AS database_name, @@autocommit AS autocommit_setting;
-- SETUP BLOCK: deliberately committed fixture, outside the assessed transaction.
-- Unique synthetic serial makes this fixture independent of seed IDs.
START TRANSACTION;
INSERT INTO Customer(customer_name, phone)
VALUES ('txc synthetic customer', '0000000000');
SET @txc_customer = LAST_INSERT_ID();
INSERT INTO Staff(staff_name, role, active_status)
VALUES ('txc synthetic technician', 'TECHNICIAN', TRUE);
SET @txc_technician = LAST_INSERT_ID();
INSERT INTO Equipment(customer_id, component_type, brand, model,
                      serial_no, physical_condition, accessories)
VALUES (@txc_customer, 'GPU', 'TEST', 'TX-MODEL',
        CONCAT('txc-', UUID()), 'Synthetic intact condition', 'NONE');
SET @txc_equipment = LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id, request_date, fault_description, request_status)
VALUES (@txc_customer, '2026-10-30', 'txc synthetic repair', 'ACCEPTED');
SET @txc_request = LAST_INSERT_ID();
INSERT INTO RequestItem(request_id, equipment_id, item_status)
VALUES (@txc_request, @txc_equipment, 'AWAITING_DELIVERY');
SET @txc_item = LAST_INSERT_ID();
INSERT INTO Quotation(request_id, quotation_version, quoted_amount,
                      quotation_date, quotation_status, customer_decision_date)
VALUES (@txc_request, 1, 500.00, '2026-10-30', 'ACCEPTED', '2026-10-30');
COMMIT;
SELECT 'TXC01_BEFORE' AS test_id, r.request_id, r.request_status,
       ri.request_item_id, ri.item_status, j.job_id, j.job_status
FROM ServiceRequest r
JOIN RequestItem ri ON ri.request_id = r.request_id
LEFT JOIN ServiceJob j ON j.request_item_id = ri.request_item_id
WHERE ri.request_item_id = @txc_item;

-- ASSESSED TRANSACTION: accepted quote and active TECHNICIAN exist in setup.
START TRANSACTION;
UPDATE RequestItem SET item_status = 'RECEIVED'
WHERE request_item_id = @txc_item AND item_status = 'AWAITING_DELIVERY';
INSERT INTO ServiceJob(request_item_id, technician_id, received_date, job_status)
VALUES (@txc_item, @txc_technician, '2026-10-31', 'RECEIVED');
SET @txc_job = LAST_INSERT_ID();
UPDATE ServiceRequest SET request_status = 'IN_PROGRESS'
WHERE request_id = @txc_request AND request_status = 'ACCEPTED';
COMMIT;
SELECT 'TXC01_AFTER' AS test_id, r.request_id, r.request_status,
       ri.request_item_id, ri.item_status, j.job_id, j.job_status
FROM ServiceRequest r
JOIN RequestItem ri ON ri.request_id = r.request_id
LEFT JOIN ServiceJob j ON j.request_item_id = ri.request_item_id
WHERE ri.request_item_id = @txc_item;

SELECT 'TXC01' AS test_id,
       IF(COUNT(*) = 1, 'PASS', 'FAIL') AS result,
       COUNT(*) AS persisted_receipts
FROM ServiceRequest r
JOIN RequestItem ri ON ri.request_id = r.request_id
JOIN ServiceJob j ON j.request_item_id = ri.request_item_id
WHERE r.request_id = @txc_request AND r.request_status = 'IN_PROGRESS'
  AND ri.request_item_id = @txc_item AND ri.item_status = 'RECEIVED'
  AND j.job_id = @txc_job AND j.job_status = 'RECEIVED'
  AND j.technician_id = @txc_technician AND j.received_date = '2026-10-31';
