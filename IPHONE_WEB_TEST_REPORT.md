# IPHONE WEB TEST REPORT

- Product: Field Time
- Version: v1.0.0 - Field Operations Baseline
- Date: 2026-08-02
- Target priority: iPhone Safari, iPad Safari, Android later
- Build target: Flutter Web
- Base href: /field-time/

## Commands Executed

- flutter clean: passed
- flutter pub get: passed
- dart format .: passed
- flutter analyze: passed, no issues found
- flutter test: passed, 9 tests passed
- flutter build web --base-href /field-time/: passed, build/web generated

## Local Web Validation

- Local URL: http://127.0.0.1:8080/field-time/
- Local app HTTP status: 200
- Local jobs asset HTTP status: 200
- Local jobs asset path: http://127.0.0.1:8080/field-time/assets/assets/data/jobs.json
- Jobs loaded from local build asset: 23
- Active jobs loaded from local build asset: 23
- Inactive jobs loaded from local build asset: 0
- Client found in jobs asset: EWW
- Console errors in automated viewport checks: none
- Failed network requests in automated viewport checks: none

## iPhone Width Check

- Emulated viewport: iPhone 13, 390px wide
- Render result: app loaded and rendered
- Layout overflow check: scrollWidth matched viewport width
- Screenshot evidence:
  - visual_qa/iphone_web_local_390.png
  - visual_qa/iphone_web_jobs_tab_390.png

## iPad Width Check

- Emulated viewport: iPad Pro 11
- Render result: app loaded and rendered
- Layout overflow check: scrollWidth matched viewport width
- Screenshot evidence:
  - visual_qa/ipad_web_jobs_tab.png
  - visual_qa/ipad_web_job_selector.png

## Safari/PWA Readiness

- web/index.html includes apple-mobile-web-app-capable.
- web/index.html includes apple-mobile-web-app-title.
- web/manifest.json uses display: standalone.
- web/manifest.json start_url: /field-time/.
- web/manifest.json scope: /field-time/.
- Home Screen installation readiness: compatible metadata is present.

## Safari Compatibility Notes

- Camera uses image_picker, which presents browser-compatible camera/gallery prompts on web.
- GPS uses geolocator with service and permission checks before requesting position.
- Downloads/exports should be treated as browser-initiated downloads on Safari; no production blocker was found in this stage.
- This Windows validation used Microsoft Edge/Chromium with iPhone/iPad viewport emulation. A physical Safari device check is still recommended before declaring a real-device Safari sign-off.

