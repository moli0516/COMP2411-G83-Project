-- Index: idx_corrective_action_due_date
-- Target query: Q03 - overdue corrective actions awaiting verification.
--
-- Supported predicate:
--     due_date < '2026-10-31'
--
-- Expected benefit:
-- The due_date index provides a possible range-access path for finding
-- actions due before the reporting date. It can reduce the candidate
-- rows examined when that date range selects a small fraction of the
-- CorrectiveAction table.
--
-- Limitations:
-- action_status is not indexed here, so the index alone cannot apply
-- the complete Q03 filter or cover all selected columns.
-- MySQL may prefer a table scan for a small table or a broad date range.
--
-- Costs:
-- Additional index storage and buffer-pool usage.
-- INSERTs, DELETEs, and changes to due_date require index maintenance.
--
-- No measured execution-time improvement is claimed.

CREATE INDEX idx_corrective_action_due_date
    ON CorrectiveAction (due_date);