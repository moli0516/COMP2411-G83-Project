-- N07: Duplicate quotation version
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 1062, SQLSTATE 23000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO Quotation(request_id,quotation_version,quoted_amount,quotation_date) VALUES (@nr,1,500,'2026-10-30');
