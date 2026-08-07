# JKDD TECH — Field Time — Test 04

Version: v1.1.0-test4

## Core flow
- Collaborator completed work segments sync into Supervisor Center as Pending approval records.
- Supervisor/Director approval states are persisted and mapped back to each work segment.
- Travel Bonus is preserved in approval records and PDF output.
- Pay Premium metadata is preserved for percentage, fixed-hourly, and double-time rules.
- Official PDF includes approval status, approval summary, and audit information.

## Homologation corrections
- Header and settings identify the build as `v1.1.0-test4`.
- Login includes a Test 04 password-recovery entry point for homologation accounts.
- Draft receipts can be reopened, edited, have their image replaced, saved again, or submitted.
- Collaborator end-of-day flow no longer interrupts the user with a receipt question; it asks only for final confirmation and then displays a successful end-of-day/rest message.
- Supervisor Timesheet exposes team daily records with review actions for clock in/out, break, Travel Bonus, Pay Premium label, supervisor note, approval, rejection, and correction request.
- Six fictitious `TST-*` employees and deterministic daily records are included only for Test 04 homologation scenarios.

## Validation
GitHub Actions validates dependencies, static analysis, automated tests, and Flutter Web release build. GitHub Pages deploy remains configured on pushes to main.

## Test target
Validate the complete Collaborator → Supervisor → Director → PDF workflow using the Test 04 build before promoting the next version.
