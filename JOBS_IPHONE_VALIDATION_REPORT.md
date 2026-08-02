# JOBS IPHONE VALIDATION REPORT

- Product: Field Time
- Date: 2026-08-02
- Jobs source: assets/data/jobs.json
- Source workbook: JKDD_Banco_de_Dados_Obras.xlsx
- Source sheet: Obras JKDD

## Jobs Database

- Total jobs imported: 23
- Active jobs: 23
- Inactive jobs: 0
- Duplicate Job_ID records: 0
- Duplicate Job_Number records: 0
- Ignored rows: 0
- Required missing fields: 0
- Fictional jobs detected: none

## Required Company Data

- Client company shown in app: EWW
- Subcontractor shown in app: JKDD Finish & Remodeling Corp
- Jobs JSON metadata client: EWW
- Jobs JSON metadata subcontractor: JKDD Finish & Remodeling Corp

## Asset Loading

- Source asset exists: assets/data/jobs.json
- Build asset exists: build/web/assets/assets/data/jobs.json
- Build asset loaded locally over HTTP 200.
- Build asset contained 23 jobs.

## Selector Validation

- The clock-in job selector was opened in the iPad web viewport.
- The selector displayed:
  - job number
  - job name
  - full address
  - city
  - status
- The Jobs tab was opened in the iPhone-width viewport and displayed real imported jobs.
- Inactive jobs are filtered out of the clock-in selector by default.

## Defaulted Import Values

- Job_ID was set from Job_Number when Job_ID was absent.
- Job_Name was set as Obra {Job_Number} when Job_Name was absent.
- Client was set to EWW when Client was absent.
- Status was set to active when Status was absent.
- Full_Address was generated from Address, City, State, and ZIP_Code.

## Evidence

- Import report: data_import/reports/JOBS_IMPORT_REPORT.md
- iPhone jobs screenshot: visual_qa/iphone_web_jobs_tab_390.png
- iPad selector screenshot: visual_qa/ipad_web_job_selector.png

