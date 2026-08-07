# JKDD TECH — Field Time — Test 04

Version: v1.1.0-test4

## Core flow
- Collaborator completed work segments sync into Supervisor Center as Pending approval records.
- Supervisor/Director approval states are persisted and mapped back to each work segment.
- Travel Bonus is preserved in approval records and PDF output.
- Pay Premium metadata is preserved for percentage, fixed-hourly, and double-time rules.
- Official PDF includes approval status, approval summary, and audit information.

## Validation
GitHub Actions validates dependencies, static analysis, automated tests, and Flutter Web release build. GitHub Pages deploy remains configured on pushes to main.

## Test target
Validate the complete Collaborator → Supervisor → Director → PDF workflow using the Test 04 build before promoting the next version.
