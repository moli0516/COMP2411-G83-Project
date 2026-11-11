-- N02: Invalid equipment customer reference
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1452, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories) VALUES (@missing_customer,'GPU','TEST','NEG',CONCAT('NEG-',UUID()),'Intact','NONE');
