-- N01: Duplicate equipment serial
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1062, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO Equipment(customer_id,component_type,brand,model,serial_no,physical_condition,accessories) SELECT @nc,'GPU','TEST','NEG',serial_no,'Intact','NONE' FROM Equipment WHERE equipment_id=@ne;
