# Operation contracts - pending implementation

## Request registration
Inputs: Customer/equipment IDs, fault description and date.
Checks: Validate ownership and at least one distinct item; no partial request.
TODO: transaction, output, rejection mechanism and tests.

## Quotation issue and acceptance
Inputs: Request/quotation IDs, version, amount, decision date.
Checks: Positive values; unique version; one accepted quotation; protect accepted scope.
TODO: transaction, output, rejection mechanism and tests.

## Receipt and job creation
Inputs: Request-item ID, technician ID, receipt date.
Checks: Accepted quote; eligible technician; unique job; receipt and job changes atomic.
TODO: transaction, output, rejection mechanism and tests.

## Inspection and completion
Inputs: Job/inspection IDs, inspector, round, criteria, completion date.
Checks: Distinct eligible inspector; unique round/criterion; completion and overall result consistency.
TODO: transaction, output, rejection mechanism and tests.

## Incident and corrective actions
Inputs: Job, reporter, severity, action, assignee, resolution and verification data.
Checks: Medium/high incident action coverage at commit; resolution details; manager verification; shared links.
TODO: transaction, output, rejection mechanism and tests.

## Return and closure
Inputs: Job/request IDs, return date and staff ID.
Checks: Required return data; no job reopening; every request item received with CLOSED job.
TODO: transaction, output, rejection mechanism and tests.

