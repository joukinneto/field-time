# Field Time - Jobs iPhone Validation Report

Generated: 2026-08-02 20:39:20 -04:00

Project:
`C:\Users\SANTANA\Documents\Codex\JKDD_FIELD\001_SOURCE_CODE\009_JKDD_FIELD_TIME_RECORDS_PRODUCTION`

## Jobs Database

Source file:
`assets/data/jobs.json`

Bundled file:
`build/web/assets/assets/data/jobs.json`

Validation:

- Source jobs: 23.
- Bundled jobs: 23.
- Active jobs: 23.
- Inactive jobs: 0.
- Client: EWW.
- Worker/subcontractor: JKDD Finish & Remodeling Corp.
- No fictitious jobs were found in the imported database.

## Repository Flow

The app controller loads jobs through `JobAssetRepository`, converts them into Field Time domain jobs and keeps them available offline from the bundled JSON asset.

The clock-in selector filters by `job.active`, so inactive jobs are not shown by default.

## iPhone-Width UI

Local mobile-width validation confirmed that the Jobs screen displays:

- Job number.
- Job name.
- Full address including city/state/ZIP.
- Status badge.

Observed examples:

- `217 - Obra 217`, `217 Gregory Rd, West Palm Beach, FL, 33405`, Active.
- `315 - Obra 315`, `315 Ellamar Rd, West Palm Beach, FL, 33405`, Active.
- `330 - Obra 330`, `330 Apache Ln, Boca Raton, FL, 33487`, Active.

## Result

Jobs database preservation and iPhone-width jobs UI validation passed locally.
