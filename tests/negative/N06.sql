-- N06: Quotation amount must be positive
-- Prerequisite: metadata negative_setup_sql in the SAME connection.
-- Expected MySQL error 3819, SQLSTATE HY000.
-- Run through the runner; setup and verification are outside this file.
INSERT INTO Quotation(request_id,quotation_version,quoted_amount,quotation_date) VALUES (@nr,2,0,'2026-10-30');
