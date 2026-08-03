# AUTOMATIC REGISTRATION NUMBER POLICY REPORT

Project: JKDD Field - Field Time  
Developer: JKDD TECH  
Status: Implemented by file edits only  
Date: 2026-08-02

## Created Patterns

- Payroll Employee: `PAY-0001`
- Subcontractor Company: `SUB-0001`
- Subcontractor Worker: `TER-0001`
- Job: `JOB-0001`
- Receipt: `REC-000001`
- Reimbursement: `RMB-000001`
- Timesheet: `TS-000001`
- Invoice: `INV-000001`
- New Job Request: `REQ-000001`

## Entities Updated

- Employees now support:
  - `id`
  - `registrationNumber`
  - legacy-compatible `employeeId`
- Field Time operational models now support `registrationNumber` on:
  - Job
  - Subcontractor Company
  - Worker Profile
  - WorkDay / Timesheet
  - Receipt
  - Reimbursement Request
- Supervisor Center jobs now support:
  - UUID `id`
  - generated `registrationNumber`

## Sequence Mechanism

- `RegistrationNumberPolicy` centralizes prefixes, widths, UUID generation, duplicate checks and sequence formatting.
- Field Time snapshots now store `registrationSequences` by prefix.
- Timesheet, Receipt and Reimbursement creation update the stored sequence so numbers are not reduced after deletion, deactivation or archiving in local state.
- Imported jobs receive generated `JOB-0001` style numbers when no official registration number exists.

## Offline Strategy

- New records use UUIDs generated locally.
- Registration numbers are generated locally from the last known sequence.
- Temporary offline numbers are supported by policy as `PREFIX-TMP-XXXXXXXX` when reconciliation requires a temporary value.
- Sync Queue still receives created/updated records using UUID entity IDs.
- Conflict handling policy: UUID or registration number conflicts must not overwrite another record and must be reported to Sync Queue/review flow during synchronization.

## Existing Record Migration

- Existing valid visible numbers are preserved.
- Pilot subcontractor company:
  - `SUB-0001`
  - JKDD Finish & Remodeling Corp.
- Pilot responsible worker:
  - UUID added to `assets/data/employees.json`
  - `TER-0001`
  - Santana
- Existing imported job numbers remain searchable as Job Number; generated `JOB-0001` numbers are added separately as registration numbers.
- Historical employee references remain compatible with the legacy `employeeId` field.

## Duplicate Prevention

- Employee creation checks duplicate UUID, `registrationNumber` and legacy `employeeId` before saving to the local employee list.
- Registration utility includes a shared duplicate-check helper.
- Receipt, reimbursement and timesheet numbers are generated from stored local sequence state plus existing records.

## Interface Changes

- Employee form shows:
  - Registration Number
  - Generated automatically
  - read-only field
- Job request form shows:
  - Registration Number
  - Generated automatically
  - read-only field
- Supervisor Center new job form shows:
  - Registration Number
  - Generated automatically
  - read-only field

## Reports and PDFs

- Timesheet/receipt PDF paths remain English-only under the report language policy.
- Receipt tables and receipt photo pages include Registration Number when available.

## Pending Items

- Run `dart format`, `flutter analyze` and `flutter test` after approval.
- Add server-side reconciliation rules when the real synchronization backend is authorized.
- Extend sequence persistence to future admin-created employee/company records once persistent admin storage is approved.
- Add dedicated Invoice entity when invoicing is implemented.
- Add CSV/XLSX exporters with the same English-only report policy.
- Perform visual review of read-only registration fields.

## Not Executed

- No flutter clean.
- No flutter pub get.
- No dart format.
- No flutter analyze.
- No flutter test.
- No flutter build.
- No APK.
- No Web build.
- No Git, commit, push or publication.
