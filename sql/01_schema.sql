	-- INCOMPLETE: comments only; not a working schema.
-- Implement agreed dictionary, PK/FK, NOT NULL, UNIQUE, CHECK and referential actions.
-- Use transactional tables for transaction evidence.
-- Do not create/drop databases or disable FK checks.

-- TODO: Customer table and constraints.
-- TODO: Staff table and constraints.
-- TODO: Equipment table and constraints.
-- TODO: ServiceRequest table and constraints.
-- TODO: RequestItem table and constraints.
-- TODO: Quotation table and constraints.
-- TODO: ServiceJob table and constraints.
-- TODO: Inspection table and constraints.
-- TODO: InspectionResult table and constraints.
-- TODO: Incident table and constraints.
-- TODO: CorrectiveAction table and constraints.
-- TODO: IncidentCorrectiveAction table and constraints.

CREATE TABLE Customer(
	customer_id INT AUTO_INCREMENT PRIMARY KEY,
	customer_name VARCHAR(100) NOT NULL,
	phone VARCHAR(30) NOT NULL,
	email VARCHAR(254) DEFAULT NULL
);
CREATE TABLE Equipment(
	equipment_id INT AUTO_INCREMENT PRIMARY KEY,
	customer_id INT NOT NULL,
	component_type VARCHAR(20) NOT NULL,
	brand VARCHAR(50) NOT NULL,
	model VARCHAR(100) NOT NULL,
	serial_no VARCHAR(100) NOT NULL UNIQUE,
	physical_condition VARCHAR(255) NOT NULL,
	accessories VARCHAR(255) NOT NULL,
	CONSTRAINT fk_equipement_customer
	    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    CONSTRAINT chk_component_type
        CHECK (component_type in ("CPU", "GPU", "MOTHERBOARD", "RAM", "STORAGE", "PSU", "COOLER"))
);
CREATE TABLE ServiceRequest(
	request_id INT AUTO_INCREMENT PRIMARY KEY,
	customer_id INT NOT NULL,
	request_date DATE NOT NULL,
	fault_description VARCHAR(1000) NOT NULL,
	request_status VARCHAR(30) NOT NULL 
	DEFAULT "PENDING_QUOTATION",
	CONSTRAINT fk_request_customer
	    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
	CONSTRAINT chk_request_status
	    CHECK (request_status IN ("PENDING_QUOTATION","QUOTED","ACCEPTED","SUSPENDED","IN_PROGRESS", "CLOSED"))
);
CREATE TABLE RequestItem(
	request_item_id INT AUTO_INCREMENT PRIMARY KEY,
	request_id INT NOT NULL,
	equipment_id INT NOT NULL,
	item_status VARCHAR(30) NOT NULL
	DEFAULT "AWAITING_DELIVERY",
	CONSTRAINT fk_reqitem_request
	    FOREIGN KEY (request_id) REFERENCES ServiceRequest(request_id),
	CONSTRAINT fk_reqitem_equipment
	    FOREIGN KEY (equipment_id) REFERENCES Equipment(equipment_id),
	CONSTRAINT chk_item_status
	    CHECK (item_status IN ("AWAITING_DELIVERY", "RECEIVED")),
    CONSTRAINT ak_request_id_equipment_id
        UNIQUE (request_id, equipment_id)
);
CREATE TABLE Quotation(
	quotation_id INT AUTO_INCREMENT PRIMARY KEY,
	request_id INT NOT NULL,
	quotation_version INT NOT NULL,
	quoted_amount DECIMAL(10,2) NOT NULL,
	quotation_date DATE NOT NULL,
	quotation_status VARCHAR(20) NOT NULL
	DEFAULT "PENDING",
	customer_decision_date DATE,
	CONSTRAINT chk_ver_positive
	    CHECK (quotation_version > 0),
	CONSTRAINT chk_amount_positive
	    CHECK (quoted_amount > 0),
	CONSTRAINT chk_quotation_status
	    CHECK (quotation_status IN ("PENDING", "ACCEPTED", "REJECTED", "REVISED")),
	CONSTRAINT fk_quotation_request
	    FOREIGN KEY (request_id) REFERENCES ServiceRequest(request_id),
    CONSTRAINT ak_request_id_quotation_version
        UNIQUE (request_id, quotation_version),
    CONSTRAINT chk_decision_date
        CHECK (
            quotation_status NOT IN ("ACCEPTED", "REJECTED") OR (
            customer_decision_date IS NOT NULL AND quotation_status IN ("ACCEPTED", "REJECTED"))
        )
);
CREATE TABLE Staff(
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    staff_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL,
    phone VARCHAR(30) DEFAULT NULL,
    email VARCHAR(254) DEFAULT NULL,
    active_status BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_role
        CHECK (role in ("TECHNICIAN", "INSPECTOR", "MANAGER"))
);
CREATE TABLE ServiceJob(
    job_id INT AUTO_INCREMENT PRIMARY KEY,
    request_item_id INT NOT NULL UNIQUE,
    technician_id INT NOT NULL,
    received_date DATE NOT NULL,
    job_status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED',
    repair_description VARCHAR(1000) DEFAULT NULL,
    repair_completed_date DATE DEFAULT NULL,
    returned_date DATE DEFAULT NULL,
    returned_by_staff_id INT DEFAULT NULL,
    CONSTRAINT fk_servicejob_request_item
        FOREIGN KEY (request_item_id) REFERENCES RequestItem(request_item_id),
    CONSTRAINT fk_servicejob_technician
        FOREIGN KEY (technician_id) REFERENCES Staff(staff_id),
    CONSTRAINT fk_servicejob_returned_by_staff
        FOREIGN KEY (returned_by_staff_id) REFERENCES Staff(staff_id),
    CONSTRAINT chk_servicejob_status
        CHECK (job_status IN ('RECEIVED', 'IN_REPAIR', 'SUBMITTED_FOR_INSPECTION', 'REWORK_REQUIRED','READY_FOR_RETURN','CLOSED')),
    CONSTRAINT chk_servicejob_repair_submission
        CHECK (
            job_status <> 'SUBMITTED_FOR_INSPECTION'
            OR (repair_description IS NOT NULL AND repair_completed_date IS NOT NULL)
        ),
    CONSTRAINT chk_servicejob_return_closure
        CHECK (
            job_status <> 'CLOSED'
            OR (returned_date IS NOT NULL AND returned_by_staff_id IS NOT NULL)
        )
);
CREATE TABLE Inspection(
    inspection_id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL,
    inspector_id INT NOT NULL,
    inspection_date DATE DEFAULT NULL,
    inspection_round INT NOT NULL,
    overall_result VARCHAR(20) DEFAULT NULL,
    inspection_status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    CONSTRAINT fk_inspection_job
        FOREIGN KEY (job_id) REFERENCES ServiceJob(job_id),
    CONSTRAINT fk_inspection_inspector
        FOREIGN KEY (inspector_id) REFERENCES Staff(staff_id),
    CONSTRAINT ak_inspection_job_round
        UNIQUE (job_id, inspection_round),
    CONSTRAINT chk_inspection_round_positive
        CHECK (inspection_round > 0),
    CONSTRAINT chk_inspection_status
        CHECK (inspection_status IN ('IN_PROGRESS', 'COMPLETED')),
    CONSTRAINT chk_inspection_completed_required_fields
        CHECK (
            inspection_status <> 'COMPLETED'
            OR (inspection_date IS NOT NULL AND overall_result IN ('PASS', 'FAIL'))
        ),
    CONSTRAINT chk_inspection_in_progress_no_final_values
        CHECK (
            inspection_status <> 'IN_PROGRESS'
            OR (inspection_date IS NULL AND overall_result IS NULL)
        )
);
CREATE TABLE InspectionResult(
    inspection_result_id INT AUTO_INCREMENT PRIMARY KEY,
    inspection_id INT NOT NULL,
    criterion_name VARCHAR(30) NOT NULL,
    result VARCHAR(20) NOT NULL,
    remarks VARCHAR(1000) DEFAULT NULL,
    CONSTRAINT fk_inspectionresult_inspection
        FOREIGN KEY (inspection_id) REFERENCES Inspection(inspection_id),
    CONSTRAINT ak_inspectionresult_inspection_criterion
        UNIQUE (inspection_id, criterion_name),
    CONSTRAINT chk_inspectionresult_criterion_name
        CHECK (criterion_name IN (
            'POWER_ON',
            'FUNCTION_TEST',
            'TEMPERATURE_TEST',
            'VOLTAGE_TEST',
            'PHYSICAL_CONDITION',
            'ACCESSORY_COMPLETENESS'
        )),
    CONSTRAINT chk_inspectionresult_result
        CHECK (result IN ('PASS', 'FAIL', 'NOT_APPLICABLE'))
);
CREATE TABLE Incident(
    incident_id INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL,
    reported_by_staff_id INT NOT NULL,
    incident_date DATE NOT NULL,
    incident_type VARCHAR(50) NOT NULL,
    severity VARCHAR(10) NOT NULL,
    incident_description VARCHAR(1000) NOT NULL,
    incident_status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    CONSTRAINT fk_incident_job
        FOREIGN KEY (job_id) REFERENCES ServiceJob(job_id),
    CONSTRAINT fk_incident_reported_by_staff
        FOREIGN KEY (reported_by_staff_id) REFERENCES Staff(staff_id),
    CONSTRAINT chk_incident_type_nonempty
        CHECK (CHAR_LENGTH(TRIM(incident_type)) > 0),
    CONSTRAINT chk_incident_severity
        CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT chk_incident_description_nonempty
        CHECK (CHAR_LENGTH(TRIM(incident_description)) > 0),
    CONSTRAINT chk_incident_status
        CHECK (incident_status IN ('OPEN', 'UNDER_REVIEW', 'RESOLVED', 'CLOSED'))
);

CREATE TABLE CorrectiveAction(
    action_id INT AUTO_INCREMENT PRIMARY KEY,
    action_description VARCHAR(1000) NOT NULL,
    assigned_staff_id INT NOT NULL,
    created_date DATE NOT NULL,
    due_date DATE NOT NULL,
    action_status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    resolved_date DATE DEFAULT NULL,
    resolution_note VARCHAR(1000) DEFAULT NULL,
    verified_by_manager_id INT DEFAULT NULL,
    verified_date DATE DEFAULT NULL,
    CONSTRAINT fk_correctiveaction_assigned_staff
        FOREIGN KEY (assigned_staff_id) REFERENCES Staff(staff_id),
    CONSTRAINT fk_correctiveaction_verified_manager
        FOREIGN KEY (verified_by_manager_id) REFERENCES Staff(staff_id),
    CONSTRAINT chk_correctiveaction_description_nonempty
        CHECK (CHAR_LENGTH(TRIM(action_description)) > 0),
    CONSTRAINT chk_correctiveaction_due_date
        CHECK (due_date >= created_date),
    CONSTRAINT chk_correctiveaction_status
        CHECK (action_status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'VERIFIED')),
    CONSTRAINT chk_correctiveaction_resolved_state
        CHECK (
            action_status IN ('OPEN', 'IN_PROGRESS')
            OR (resolved_date IS NOT NULL AND resolution_note IS NOT NULL)
        ),
    CONSTRAINT chk_correctiveaction_verified_state
        CHECK (
            action_status <> 'VERIFIED'
            OR (
                resolved_date IS NOT NULL
                AND resolution_note IS NOT NULL
                AND verified_by_manager_id IS NOT NULL
                AND verified_date IS NOT NULL
            )
        ),
    CONSTRAINT chk_correctiveaction_open_progress_nulls
        CHECK (
            action_status NOT IN ('OPEN', 'IN_PROGRESS')
            OR (
                resolved_date IS NULL
                AND resolution_note IS NULL
                AND verified_by_manager_id IS NULL
                AND verified_date IS NULL
            )
        )
);

CREATE TABLE IncidentCorrectiveAction(
    incident_id INT NOT NULL,
    action_id INT NOT NULL,
    PRIMARY KEY (incident_id, action_id),
    CONSTRAINT fk_incidentcorrectiveaction_incident
        FOREIGN KEY (incident_id) REFERENCES Incident(incident_id),
    CONSTRAINT fk_incidentcorrectiveaction_action
        FOREIGN KEY (action_id) REFERENCES CorrectiveAction(action_id)
);