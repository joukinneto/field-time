# Field Time

Field Time by JKDD TECH is a Flutter app for field time records, job switching, receipts, reimbursements and timesheet review.

Current approved version: `v1.0.0 - Field Operations Baseline`

Flutter package version: `1.0.0+10`

## Web Test Build

The GitHub Pages test build is configured for:

```bash
flutter build web --release --base-href "/field-time/"
```

This repository is prepared for GitHub Pages deployment through GitHub Actions. The deployment is a test publication only and is not an App Store or TestFlight release.

## Local Validation

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build web --release --base-href "/field-time/"
```
