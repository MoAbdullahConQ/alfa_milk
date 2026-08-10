# ALFA MILK — Project Context

> **Purpose:** A single, self-contained orientation document for any developer, AI agent, chat model, or cloud service. Reading only this file should be enough to understand **what we're building, where we are, and what to do next**.
>
> **Authoritative source of truth is the repository itself** (code + Spec Kit artifacts under `specs/001-alpro-dairysense-converter/`). If this file conflicts with the repo, trust the repo and update this file.

---

## 1. Executive Summary

- **Project:** Alfa Milk — a local-first **Flutter desktop** app that converts an **Alpro** milking report (HTML) into a **DairySense** import file (XLSX), filtered by a user-managed **current cow list**.
- **No backend, login, or cloud** for the MVP. Runs offline on Windows.
- **Architecture:** feature-first Clean Architecture (`features/*/{data,domain,presentation}`) + shared `core/`; `flutter_bloc` Cubit for state; `dartz.Either<Failure, T>` at the data/domain boundary.
- **Status:** Phases 1–5 complete (Setup, Foundation, US1, US2 impl, US3). US4 (save flow) is **next**.
- **Progress:** **16 of 27 tasks done**; 11 pending. `flutter analyze` clean; all written unit tests pass.
- **Known bug to fix immediately:** the convert step still writes the output over the *source report path* (placeholder), which can corrupt the source. US4/T019 fixes this.

---

## 2. What We're Building

### The conversion

```text
Alpro HTML (milking report)
        +
Current DairySense cow list (filter)
        ↓
Filtered/transformed DairySense XLSX
```

- **Alpro** exports milking data as HTML.
- **DairySense** manages the herd and imports milking data via a specific Excel format.
- The cow-number list is a **filter** (which cows to include), NOT a number-mapping.

### Tech stack

Flutter · Dart · Windows desktop · `html` (parse) · `excel` (read/write) · `file_picker` · `path_provider` · `path` · `flutter_bloc` · `dartz`. No code generation.

---

## 3. Where We Are (Phase-by-Phase)

| Phase | User story | Status | Tasks |
|------:|-----------|:------:|-------|
| 1 | Setup | ✅ done | T001–T003 |
| 2 | Foundational (models + fixtures dir) | ✅ done | T004–T005 |
| 3 | US1 — Convert report (pipeline + UI shell) | ✅ done | T006–T012 |
| 4 | US2 — Trust the cow list | 🟡 impl done, tests deferred | T013, T016 deferred; T014, T015, T017 done |
| 5 | US3 — Never lose track of missing cows | ✅ done | T018 |
| 6 | US4 — Choose where files go, every time | ⬜ **next** | T019, T020 |
| 7 | Integration, performance & polish | ⬜ pending | T021, T026, T027, T022–T025 |

### Task list (authoritative: `tasks.md`)

- **Done (16):** T001–T012, T014, T015, T017, T018
- **Pending (11):** T013, T016, T019, T020, T021, T022, T023, T024, T025, T026, T027

### What's actually implemented in code

- **Pipeline (pure, testable, no UI):** Alpro HTML parser (header-index column mapping), cow-list loader/store (local persistence), filter by cow list, missing-cow detection, row builder (`Conductivity`/`temperature = 0`, `Milking Time` in seconds), XLSX writer (8 headers in exact order), `ConversionRepoImpl` running the pipeline in `Isolate.run`.
- **Domain:** `AlproRecord`, `AlproReport`, `CowList`, `DairySenseRow`, `ConversionResult`; use cases `FilterRecords`, `DetectMissingCows`, `BuildDairySenseRows`, `ConvertReport`.
- **UI:** `MainScreen` shell in `lib/main.dart`; cow-list card (count + last-updated + source, Update/import, restore-after-restart); report-convert view with `Select HTML file`, `CONVERT`, summary dialog.
- **US3 (T018):** `CONVERT` now runs a **preview** (parse + filter + detect missing) first; missing cows → `[Cancel] [Continue]` dialog (Cancel = no file, Continue = export found only); **no-cow-list guard** (`NoCowListError`) before anything; **zero-match guard** (FR-021, no file).

---

## 4. Next Action (do this next)

Ordered plan for the next session. **Run `flutter analyze` and `flutter test` after each step.**

1. **T019 — US4 save flow (fixes the source-overwrite bug).** In `report_convert_view.dart`, after the missing-cow **Continue**: call `FilePicker.platform.saveFile(fileName: 'DairySense_Import_<YYYY-MM-DD_HHmmss>.xlsx', type: FileType.custom, allowedExtensions: ['xlsx'])`, then run `runConversion` with the chosen path. Collision → friendly `OutputWriteError` + retry. Replaces the current `outputXlsxPath: htmlPath` placeholder.
2. **T020 — typed error handling.** Wrap every pipeline call in the UI; show typed `AlertDialog`s (`AlproParseError`, `CowListError`, `OutputWriteError`, `NoCowListError`); never show stack traces. Ensure empty `cowNumbers` maps to `NoCowListFailure`.
3. **T013 / T016 — US2 tests** (deferred): cow-list loader + store round-trip tests.
4. **T026 / T027 — perf + no-list guard + non-mutation + large-list tests.**
5. **T021 — real-file integration test** (graceful skip until real fixtures arrive; then verify/adjust header maps against the fixtures).
6. **T022–T025 — quality gates:** `flutter analyze`, full `flutter test`, `flutter build windows`, manual acceptance walk-through (quickstart.md §4 cases A–E).

**Do not** restart Spec Kit from scratch, redesign the architecture, hard-code cow counts, or invent real-file structures.

---

## 5. Core Business Rules & Invariants (non-negotiable)

1. **Cow list is a filter, not a mapping.** Match rule: `Alpro Cow No. ∈ Current Cow List`. Row order irrelevant. Never create `Alpro→DairySense` number mappings.
2. **Cow count is variable.** Never hard-code a count (e.g. "41 cows"). Support any valid list size. ~147 sample records is not a limit.
3. **No cow list → no export.** If none is saved and user converts: stop, explain, ask to import. Do NOT export everything.
4. **Missing selected cows must be surfaced.** Never silently ignore them. Cancel ⇒ no output; Continue ⇒ export only found.
5. **Never invent measurements.** `Conductivity = 0`, `temperature = 0`.
6. **Output date comes from Alpro** (not `DateTime.now()`). Session comes from the report (not hard-coded "Session 1").
7. **Preserve previous valid cow list.** A failed import never destroys the saved list (overwrite only after validation).
8. **Output folder is user-selected every time** a workbook is generated (never silently to Downloads/Desktop/etc.).
9. **Keep conversion logic out of the UI** — pipeline must stay independently testable.
10. **Never invent file structures.** Real Alpro/DairySense files are the authority for formats.

---

## 6. Transformation Rules (field mapping)

| Output column | Source / rule |
|---|---|
| `Date` | Date from Alpro report |
| `Session` | Session from Alpro report |
| `UnitNo` | Alpro `MPC Address` |
| `CowNumber` | Alpro `Cow No.` |
| `Milking Time` | Alpro `Milk Dur.` (HH:MM:SS) → total seconds |
| `Milk yield` | Alpro `Milk Yield` |
| `Conductivity` | `0` |
| `temperature` | `0` |

**Milking Time** = hours×3600 + minutes×60 + seconds (e.g. `00:03:00` → `180`).

**Exact output XLSX shape** (sheet name/count, header row, column order, types, formatting) must match the real DairySense template — verify against the fixture, do not invent.

---

## 7. Complete Pipeline

```text
Select Alpro HTML → Parse → Validate → Load current cow list
  → (optionally import + validate + save new list) → Filter by Cow No.
  → Detect selected cows missing from Alpro → Ask user (Cancel/Continue)
  → Transform matching records → Validate output → Create XLSX
  → Ask user for output folder → Save → Show summary
```

Do not partially generate the workbook before validation completes.

---

## 8. Architecture & Code Layout

Feature-first Clean Architecture; dependencies point inward:

```text
main.dart (shell, composition root)
   → features/*/presentation   (bloc Cubit + views/widgets)
   → features/*/domain         (entities, repo abstraction, use cases)
   → features/*/data           (parsers, writer, repo impl, persistence)
   → external infrastructure
```

```text
lib/
├── main.dart
├── core/
│   ├── errors/            failures.dart, custom_exceptions.dart
│   ├── helper_functions/  error_dialog.dart, file_picker_helper.dart,
│   │                      show_conversion_summary.dart, show_missing_cows_dialog.dart
│   └── utils/             app_utils.dart (normalizeHeader, normalizeCowNumber, durationToSeconds)
└── features/
    ├── home/
    │   ├── data/data_sources/   alpro_parser.dart, dairy_sense_writer.dart
    │   ├── data/repos/          conversion_repo_impl.dart
    │   ├── domain/entities/     alpro_record, alpro_report, cow_list, dairy_sense_row, conversion_result
    │   ├── domain/repos/        conversion_repo.dart
    │   ├── domain/use_cases/    filter_records, detect_missing_cows, build_dairy_sense_rows, convert_report
    │   └── presentation/        manager/conversion_cubit/, views/main_screen.dart, views/widgets/
    └── cow_list/
        ├── data/   cow_list_loader.dart, cow_list_store.dart
        └── presentation/  cow_list_card.dart
```

**Error flow:** data source throws typed exception → `ConversionRepoImpl` catches → maps to `Failure` → returns `Either<Failure, T>` → use case/Cubit → UI. Never show raw stack traces.

**Persistence:** `getApplicationSupportDirectory()/cow_list.json` (cow numbers + last-updated). Survives restart.

---

## 9. Testing & Performance

- **Pipeline must be testable without the UI.** Unit tests already cover parser, normalization, filtering, missing-cow detection, duration conversion, output mapping, `0` defaults, and workbook round-trip (`test/converter_test.dart`, `test/alpro_parser_test.dart`).
- **Cow-list tests (T013/T016)** are deferred — loader/store round-trip in a temp dir.
- **Real-file integration (T021):** real Alpro HTML + real cow list + real DairySense template → generated XLSX; verify row count, cow numbers, yields, seconds, date/session, `0` columns, structure, column order. **Skip gracefully** if fixtures absent; when they arrive, adjust header maps/constants to match and keep files as regression fixtures.
- **Performance:** support several thousand records; never block/freeze the UI (heavy work in `Isolate.run`). Sample sizes are not limits.

---

## 10. MVP Non-Goals

Modifying Alpro/DairySense, cloud sync/login/database, herd sync, number mapping, automatic output-folder selection, invented conductivity/temperature values, manual mapping config.

---

## 11. Fixture Requirement (very important)

Real supplied files to obtain and inspect: **Alpro HTML report**, **DairySense import Excel template**, **current DairySense cow-number Excel**. They are the authority for all format details. Do not invent sheet names, header rows, date formats, column positions, session values, or missing-value behavior. Keep them as regression fixtures.

---

## 12. Known Open Questions

1. Is the cow number always in one fixed Excel column, or auto-detected? *(partially resolved: loader auto-detects `Cow Number` header, falls back to first numeric column)*
2. What exact date format does DairySense require?
3. Can Alpro reports contain sessions other than "Session 1"?
4–5. Behavior for missing/invalid `Milk Dur.` / `Milk Yield`? *(resolved in code: such rows are skipped with a warning)*
6. Are cow numbers always integers? *(assumed integer; normalization trims/parses)*
7. Required output filename? *(convention `DairySense_Import_<ts>.xlsx` proposed)*
8. Does the workbook require a specific sheet name / multiple sheets?
9. Drag-and-drop support?
10. Preview filtered records before export? *(partially: missing-cow preview exists)*

Resolved items take precedence via the artifacts/implementation.

---

## 13. Definition of Done (MVP complete when)

Windows build succeeds; supplied Alpro parses; supplied cow list imports; any valid list size works; only selected cows exported; missing cows require confirmation; latest valid list persists; new list replaces old; failed update preserves old; correct workbook structure; `Conductivity=0`, `temperature=0`; duration→seconds correct; output folder chosen every time; invalid input never crashes; automated tests cover core rules; end-to-end conversion passes on real files; final quality gates pass.

---

## 14. How an Agent Should Continue

1. Read this file (orientation).
2. Read authoritative Spec Kit files: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, `tasks.md` (under `specs/001-alpro-dairysense-converter/`).
3. Inspect repo: `git status`, `lib/`, `test/`, `pubspec.yaml`.
4. Read `tasks.md` and trust its `[ ]`/`[X]` state over this file.
5. Inspect real fixtures before assuming file formats; don't invent them.
6. Continue from the first relevant incomplete task (currently **T019**).
7. Run `flutter analyze` + `flutter test` after each change; keep them green.

### Source-of-truth hierarchy

```text
1. Actual repository implementation/files
2. Current Spec Kit artifacts
3. Actual supplied fixtures
4. This project-context file
5. Older summaries / conversations
```

---

*Last updated: 2026-08-10.*
