# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

No code changes since 1.0.0. Work after 1.0.0 is planned as eight independently shippable
releases plus one non-shippable spike; the authoritative plan is Part 2 of
[`docs/alpro_dairysense_plan.md`](docs/alpro_dairysense_plan.md) (§32 phases, §35 roll-up).

### Planned

- **1.1.0 — Distribution & cow-list durability**: Inno Setup installer, fixed
  `%ProgramData%\AlfaMilk\` data root with one-time copy-migration, atomic JSON writes with
  `.bak`, **Restore previous list…**, nullable `lastUpdated` + ~30-day staleness warning,
  implausible-cow-number check on cow-list import, rolling support log.
- **1.2.0 — Multi-session merge**: any number of Alpro HTML files → one workbook, sorted
  date → session → source order; duplicate `(Date, Session)` is a hard block; a batch is
  all-or-nothing. **Blocked on acceptance cases H–K** (plan §33.5).
- **1.3.0 — Live progress & drag and drop**: `SendPort` progress out of the batch isolate,
  multi-file dropzone, single-instance guard.
- **1.4.0 — History, ledger & workbook inspector**: `NavigationRail` shell, history page
  (one JSON file per entry, no index), import ledger, and read-back of any DairySense
  workbook including pre-ledger ones.
- **1.5.0 — One-click DairySense import**: in-process `dart:ffi` automation of
  `MilkIntegration.exe` with four outcomes (`success` / `failure` / `unknown` /
  `precondition_failed`) and an always-available manual fallback. Preceded by a
  non-shippable spike that answers §29.8's unknowns.
- **1.6.0 — History polish**: retention cap that always asks, history export to Excel/PDF,
  diagnostics zip, and a read-only licence request-code readout.
- **1.7.0 — Licensing**: hardware-locked activation with two states only (`licensed` /
  `blocked`) that never destroys local data.
- **1.8.0 — UI redesign, dashboard & dark mode**: last, by design.

## [1.0.0] - 2026-08-14

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
- `flutter analyze` clean; `flutter test` green (52 unit + integration tests, including the fixture-based end-to-end test).
- **T024** — Windows build verified: VS2022 C++ workload, `flutter build windows` succeeds, EXE launches.
- **T025** — Manual acceptance A–G + edge checks all pass on the built EXE with the real customer files.
- Real customer fixtures now shipped in `test/fixtures/`: `alpro_report.html` (147 records), `current_cow_list.xlsx` (41 cows), `dairy_sense_template.xlsx`.

### Fixed

- Integration test header assertion aligned with the verified DairySense output format (`CowNumber - in dairysense number-`, `Milking Time -in seconds-`); the test now runs green against the real fixtures.

### Windows build notes

- `windows/CMakeLists.txt` pins the Windows SDK to `10.0.20348.0` (the 10.0.22621.0 Desktop C++ component is incomplete).
- `analysis_options.yaml` excludes generated `build/` and platform dirs from the analyzer.
