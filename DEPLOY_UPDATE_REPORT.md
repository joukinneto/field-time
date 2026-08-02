# DEPLOY UPDATE REPORT

- Product: Field Time
- Date: 2026-08-02
- Repository: https://github.com/joukinneto/field-time.git
- Branch: main
- Pages base href: /field-time/

## Pre-Deploy Validation

- flutter clean: passed
- flutter pub get: passed
- dart format .: passed
- flutter analyze: passed
- flutter test: passed, 9 tests passed
- flutter build web --base-href /field-time/: passed
- build/web exists: yes
- Local build URL returned HTTP 200: yes
- Local build jobs asset returned HTTP 200: yes
- Local build jobs count: 23

## Deployment

- Git commit: 6d3157218982b943ae39740906808468e8d7a11b
- GitHub push: completed
- GitHub Actions run: https://github.com/joukinneto/field-time/actions/runs/30773198407
- GitHub Pages publish: completed
- Published URL: https://joukinneto.github.io/field-time/
- Published HTTP 200: yes
- Published jobs asset URL: https://joukinneto.github.io/field-time/assets/assets/data/jobs.json
- Published jobs asset HTTP 200: yes
- Published jobs asset count: 23
- Published active jobs: 23
- Published inactive jobs: 0
- Published client: EWW
- Published source workbook: JKDD_Banco_de_Dados_Obras.xlsx
- Published source sheet: Obras JKDD
- Published iPhone-width validation: passed at 390px width
- Published iPhone-width overflow check: passed, scrollWidth matched viewport width
- Published console/request check: no console errors and no failed requests in automated viewport check

## Result

- Status: deployed and validated
