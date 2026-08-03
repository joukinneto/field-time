# Field Time - iPhone Web Test Report

Generated: 2026-08-02 20:39:20 -04:00

Project:
`C:\Users\SANTANA\Documents\Codex\JKDD_FIELD\001_SOURCE_CODE\009_JKDD_FIELD_TIME_RECORDS_PRODUCTION`

URL target:
`https://joukinneto.github.io/field-time/`

## Local Build Tested

Command:
`flutter build web --base-href /field-time/`

Result:
Passed. Final build generated `build\web`.

## iPhone-Width Validation

Validated locally with Edge/Chromium mobile emulation using iPhone 13 profile:

- Viewport width: 390 px.
- App title: Field Time.
- Base path: `/field-time/`.
- Runtime loaded `assets/assets/data/jobs.json`.
- Home screen rendered correctly after runtime startup.
- Bottom navigation remained usable in mobile width.
- Jobs screen rendered real jobs as cards.

## PWA / Home Screen Readiness

Validated in `build\web`:

- `manifest.json` exists.
- `start_url`: `/field-time/`.
- `scope`: `/field-time/`.
- `display`: `standalone`.
- `apple-mobile-web-app-capable`: present.
- `apple-mobile-web-app-title`: Field Time.
- `apple-touch-icon`: present.

## Safari Compatibility Notes

The code uses browser-supported flows for:

- GPS through `geolocator`.
- Camera/gallery through `image_picker`.
- PDF preview/share through `printing`.

Physical Safari permission behavior was not tested in this Windows environment. This remains required before declaring production readiness for iPhone field use.

## Result

Local iPhone-width web validation passed. Physical iPhone Safari validation remains pending.
