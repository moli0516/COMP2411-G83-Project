# Architecture

SQL-first: DBeaver -> MySQL; tracked construction/operation/query/test scripts -> evidence.
Each developer uses a separate database, built from the same committed schema and seed.
Alternative: separate desktop-hosted development databases, not concurrent mutation of one baseline.
Maintain a local presentation database. No web app/classes/REST server are required.

## Modules
Intake: Customer, Equipment, ServiceRequest, RequestItem, Quotation.
Repair/quality: Staff, ServiceJob, Inspection, InspectionResult.
Incident/action: Incident, CorrectiveAction, IncidentCorrectiveAction.
Analytics: read-only queries and useful views.

## Integrity
Structural constraints plus documented controlled SQL operations.
Detection is not prevention. Document direct-update limitations and update/delete paths.
The final ER model, dictionary and SQL must agree.
