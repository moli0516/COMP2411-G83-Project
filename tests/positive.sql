-- positive.sql | POS01-POS03
-- Run on a disposable freshly seeded database, before other mutation tests.
-- Same connection throughout. No active transaction before starting.
-- All verification rows should report PASS. Stop and ROLLBACK on any
-- unexpected error. These tests cover CRUD, not every workflow rule.
SELECT DATABASE() AS database_name, @@autocommit AS autocommit_setting;
START TRANSACTION;

-- POS01: register one owned component and a non-empty repair request.
INSERT INTO Customer(customer_name, phone, email)
VALUES ('POS synthetic customer', '0000000000', NULL);
SET @pos_customer = LAST_INSERT_ID();
INSERT INTO Equipment(customer_id, component_type, brand, model,
                      serial_no, physical_condition, accessories)
VALUES (@pos_customer, 'GPU', 'TEST', 'POS-MODEL',
        CONCAT('POS-', UUID()), 'Synthetic intact condition', 'NONE');
SET @pos_equipment = LAST_INSERT_ID();
INSERT INTO ServiceRequest(customer_id, request_date, fault_description)
VALUES (@pos_customer, '2026-10-30', 'POS synthetic display fault');
SET @pos_request = LAST_INSERT_ID();
INSERT INTO RequestItem(request_id, equipment_id)
VALUES (@pos_request, @pos_equipment);
SET @pos_item = LAST_INSERT_ID();
SELECT 'POS01' AS test_id,
       IF(COUNT(*) = 1, 'PASS', 'FAIL') AS result,
       COUNT(*) AS matching_owned_items
FROM ServiceRequest r
JOIN RequestItem ri ON ri.request_id = r.request_id
JOIN Equipment e ON e.equipment_id = ri.equipment_id
WHERE r.request_id = @pos_request
  AND e.customer_id = r.customer_id
  AND ri.item_status = 'AWAITING_DELIVERY';

-- POS02: issue a positive total quotation and update request progress.
SELECT 'POS02_BEFORE' AS test_id, request_id, request_status
FROM ServiceRequest WHERE request_id = @pos_request;
INSERT INTO Quotation(request_id, quotation_version, quoted_amount,
                      quotation_date, quotation_status)
VALUES (@pos_request, 1, 500.00, '2026-10-30', 'PENDING');
SET @pos_quote = LAST_INSERT_ID();
UPDATE ServiceRequest SET request_status = 'QUOTED'
WHERE request_id = @pos_request AND request_status = 'PENDING_QUOTATION';
SELECT 'POS02' AS test_id,
       IF(COUNT(*) = 1, 'PASS', 'FAIL') AS result,
       COUNT(*) AS matching_quoted_requests
FROM ServiceRequest r JOIN Quotation q ON q.request_id = r.request_id
WHERE r.request_id = @pos_request AND r.request_status = 'QUOTED'
  AND q.quotation_id = @pos_quote AND q.quoted_amount = 500.00
  AND q.quotation_status = 'PENDING';

-- POS03: permitted removal of an unaccepted synthetic request.
-- No accepted quotation or service job exists. Remove children first.
DELETE FROM Quotation
WHERE quotation_id = @pos_quote AND quotation_status = 'PENDING';
DELETE FROM RequestItem WHERE request_item_id = @pos_item;
DELETE FROM ServiceRequest WHERE request_id = @pos_request;
DELETE FROM Equipment WHERE equipment_id = @pos_equipment;
DELETE FROM Customer WHERE customer_id = @pos_customer;
COMMIT;
SELECT 'POS03' AS test_id,
       IF((SELECT COUNT(*) FROM Customer WHERE customer_id = @pos_customer) = 0
          AND (SELECT COUNT(*) FROM Equipment WHERE equipment_id = @pos_equipment) = 0
          AND (SELECT COUNT(*) FROM ServiceRequest WHERE request_id = @pos_request) = 0
          AND (SELECT COUNT(*) FROM RequestItem WHERE request_item_id = @pos_item) = 0
          AND (SELECT COUNT(*) FROM Quotation WHERE quotation_id = @pos_quote) = 0,
          'PASS', 'FAIL') AS result;
