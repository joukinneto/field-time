# FIELD TIME SPRINT TEST 03 REPORT

Project: JKDD Field - Field Time  
Developer: JKDD TECH  
Version: v1.1.0-test3  
Environment: Test / Homologation  
Date: 2026-08-03

## Summary

Sprint Test 03 implemented a real local homologation login, removed the manual profile selector from the app interface, restricted the visible profile model to Collaborator, Supervisor, and Director, and corrected critical operational flows around approvals, Timesheet PDF generation, route selection, persistence, and iPhone-oriented layout.

## Implemented Items

- Added startup login screen before Home.
- Added three temporary homologation accounts.
- Persisted login session locally.
- Added Logout with confirmation.
- Removed the manual profile selector from Settings.
- Restricted active visible profiles to Collaborator, Supervisor, and Director.
- Connected login role to RBAC permissions.
- Blocked Collaborator access to Management.
- Kept Supervisor and Director access to Management and Hour Approval.
- Prevented users from approving or rejecting their own time records.
- Changed correction request status to Correction Requested.
- Added local persistence for Supervisor Center operational state.
- Added Travel Bonus editing in administrative job operations.
- Added Director-only Pay Premium editing in administrative job operations.
- Updated Timesheet PDF generation to validate empty periods and show success/error messages.
- Added period-aware PDF generation for Today, Week, Month, and Year.
- Kept official reports/PDFs in English.
- Removed financial receipt amount from operational employee PDF receipt summary.
- Cleaned job labels to avoid redundant names.
- Updated map selector to show only Waze, Google Maps, and Apple Maps without technical URLs.
- Added Route to Job label to navigation buttons.
- Increased Timesheet summary card room to reduce text clipping.
- Updated visible version to v1.1.0-test3.

## Not Implemented / Deferred

- Physical iPhone Safari validation still requires the real device.
- Automated screenshots for all requested screens were not completed because the local temporary server refused the Chrome headless connection.
- Advanced Director profile administration is deferred.
- Full custom RBAC editor is deferred.
- Deep audit-history viewer for all entity types is partial; audit logs exist for review/edit flows and job operational updates persist.

## Temporary Credentials

- Collaborator: collaborator@test.jkdd / Test123!
- Supervisor: supervisor@test.jkdd / Test123!
- Director: director@test.jkdd / Test123!

## Files Created

- lib/src/auth/auth_session.dart
- lib/src/presentation/screens/login_screen.dart
- test/unit/auth_session_test.dart
- test/widget/job_navigation_button_test.dart
- FIELD_TIME_SPRINT_TEST_03_REPORT.md

## Files Modified

- lib/main.dart
- lib/shared/widgets/jkdd_app_bar.dart
- lib/shared/widgets/jkdd_job_navigation_button.dart
- lib/shared/widgets/jkdd_summary_card.dart
- lib/src/localization/app_language.dart
- lib/src/presentation/screens/time_records_screen.dart
- lib/src/presentation/screens/timesheet_screen.dart
- lib/src/supervisor_center/supervisor_center_controller.dart
- lib/src/supervisor_center/supervisor_center_models.dart
- lib/src/supervisor_center/supervisor_center_screen.dart
- lib/src/timesheet/timesheet_pdf_service.dart
- test/unit/supervisor_approval_test.dart
- test/widget/time_action_bar_test.dart
- test/widget_test.dart

## Tests Created / Updated

- Valid Collaborator login.
- Valid Supervisor login.
- Valid Director login.
- Invalid login.
- Session persistence.
- Logout.
- Profile permissions for the three Sprint roles.
- Own-time approval prevention.
- Correction Requested status.
- Map chooser without visible URLs.
- Home actions with authenticated session.
- Version v1.1.0-test3 visible after authenticated session.

## Command Results

- flutter clean: passed.
- flutter pub get: passed.
- dart format .: passed.
- flutter analyze: passed, no issues found.
- flutter test: passed, 39 tests passed.
- flutter build web --base-href /field-time/: passed.

## Build Validation

- assets/data/jobs.json: included.
- assets/data/employees.json: included.
- Field Time logo assets: included.
- manifest.json: start_url=/field-time/, scope=/field-time/, display=standalone.
- Service Worker: included.

## Captures

- Automated full capture set: not completed.
- Attempted local capture path: visual_qa/sprint_test_03/login_390.png.
- Result: invalid capture showing local connection refused, excluded from acceptance evidence.

## Known Limitations

- Physical iPhone Safari PDF opening, sharing, saving, and printing still need device validation.
- Pay Premium is functional in the administrative job operation layer, but a richer dedicated Pay Premium editor is deferred.
- Supervisor Center persistence is local homologation persistence, prepared for future backend replacement.
- Advanced visual QA across all requested screens was not completed in this environment.

## Deployment

- Implementation commit: a4623f4ede062a2701f6832dc4b1f564cc0fbdb5.
- Implementation commit message: Implement Field Time Test 03 login and operational controls.
- GitHub Actions run: 30873829105.
- GitHub Actions result: success.
- Published URL: https://joukinneto.github.io/field-time/?v=1.1.0-test3.
- Published URL status: HTTP 200.
- Published jobs asset: HTTP 200.
- Published employees asset: HTTP 200.
- Published logo asset: HTTP 200.
- Published manifest: start_url=/field-time/, scope=/field-time/, display=standalone.
- Published Service Worker: HTTP 200.
- Published bundle contains v1.1.0-test3: yes.
- Published bundle contains homologation login accounts: yes.
- Expected URL: https://joukinneto.github.io/field-time/?v=1.1.0-test3
