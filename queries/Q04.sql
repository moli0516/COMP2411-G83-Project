-- Q04: Equipment with more than one received repair job.
-- Count service jobs, not requests or undelivered request items.
-- Expected clean-seed result: 14 equipment items.

SELECT
    e.equipment_id,
    e.serial_no,
    COUNT(*) AS repair_count,
    MIN(j.received_date) AS first_received_date,
    MAX(j.received_date) AS latest_received_date
FROM Equipment AS e
JOIN RequestItem AS ri
    ON ri.equipment_id = e.equipment_id
JOIN ServiceJob AS j
    ON j.request_item_id = ri.request_item_id
GROUP BY
    e.equipment_id,
    e.serial_no
HAVING COUNT(*) > 1
ORDER BY
    repair_count DESC,
    e.equipment_id ASC;
