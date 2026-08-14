# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.0.0-beta] - 2026-08-14

### Added

- **US1 — Convert Report**: Parse Alpro HTML reports and generate DairySense-compatible XLSX files.
  - Supports real Alpro session files with date/session extraction, dry-cow handling, and missing-cow detection.
  - XLSX format verified against official DairySense Milking Import Format template.
  - Date cells as `dd/mm/yyyy`, time cells as `hh:mm` (DairySense-compatible).

- **US2 — Trusted Cow List**: Import, validate, and persist a farm cow list.
  - Auto-detects cow-number column header (variants: "Cow Number", "CowNo", "Cow", etc.).
  - Fallback to first numeric column with user notification.
  - Persists to app support directory; auto-reused on restart.

- **US3 — Missing-Cow Safety**: Preview missing cows before conversion with confirm dialog.
  - Cancel aborts cleanly, no output file created.

- **US4 — Save Flow**: Native save dialog every conversion; editable filename with 12-hour am/pm.
  - Overwrite/retry handling with typed, user-friendly error messages.

### Verified

- Generated XLSX successfully imported into real DairySense software (sheet: Sayfa1, correct date/time formats, exact headers).
- `flutter analyze` clean; `flutter test` green (51 unit tests + integration test that skips until fixtures arrive).

### Pending (require Windows host / real customer files)

- Integration test (`T021`) lives in `test/integration_test.dart` but skips until the real `alpro_report.html`, `current_cow_list.xlsx`, and `dairy_sense_template.xlsx` fixtures are placed in `test/fixtures/`.
- Windows build (`T024`) requires VS2022 C++ workload; manual acceptance (`T025`) walk-through pending.
