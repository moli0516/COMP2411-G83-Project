-- N04: Invalid equipment component domain
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 3819, SQLSTATE HY000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories) VALUES (@nc,'COMPLETE_PC','TEST','NEG',CONCAT('NEG-',UUID()),'Intact','NONE');
