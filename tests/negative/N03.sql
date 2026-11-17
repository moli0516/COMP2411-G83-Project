-- N03: Required equipment serial cannot be NULL
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1048, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories) VALUES (@nc,'GPU','TEST','NEG',NULL,'Intact','NONE');
