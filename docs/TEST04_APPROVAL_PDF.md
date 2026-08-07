# JKDD TECH — Field Time Test 04 — Approval PDF

The official timesheet PDF reads persisted Supervisor Center review state and maps it back to each Field Time work segment through the deterministic entry id `field-{workDayId}-{segmentId}`.

The PDF includes:

- approval status per work record;
- formal summary banner (Fully Approved, Pending Approval, Review In Progress, or Rejected Records Present);
- approved/pending/review/rejected counts;
- approval audit table with reviewer, timestamp, and reason/note when available;
- existing Travel Bonus and Pay Premium fields without changing worked-hour totals.

A missing Supervisor Center approval record is treated as Pending, never as Approved.
