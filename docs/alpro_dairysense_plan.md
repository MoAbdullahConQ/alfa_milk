# Alpro → DairySense Milk Data Converter

> **Implementation status (2026-08-10):** Phases 1–6 of the Spec Kit plan are
> implemented (US1–US4). The real Alpro reports (`Session1 8-8`, `Session2 7-8`,
> `session 3 7-8`) parse and convert end-to-end (147 / 127 / 140 records; Date
> `26.08.08`; Session `1/2/3`; dry cows → `0`). Remaining work is Phase 7
> (integration test on real fixtures, perf/non-mutation tests, quality gates).
> See `tasks.md` (authoritative) and the Spec Kit under
> `specs/001-alpro-dairysense-converter/`. Decisions marked **\[decided\]**
> below are confirmed by implementation/real files.

## 1. Project Overview

Build a Flutter desktop application, primarily targeting Windows, that acts as a local data bridge between:

- **Alpro**: exports animal/milking reports as HTML.
- **DairySense**: manages the herd and imports milking data from a specific Excel format.

The application must:

1. Accept an Alpro HTML report.
2. Parse all available records.
3. Accept an optional Excel file containing the **current DairySense cow numbers**.
4. Filter Alpro records using that list.
5. Export only matching cows into the DairySense Excel format.
6. Ask the user for the output folder every time.
7. Remember the last successfully imported cow-number list.

The application is local-first. No backend, login, cloud database, or network service is required for the MVP.

---

## 2. Critical Business Rule: Cow List Is a Filter, Not a Mapping

> **Important invariant:** The number of cows in the cow-list Excel file is **not fixed** and must never be hard-coded. It may increase, decrease, or otherwise change over time. The application must always use whatever valid cow numbers are present in the latest/current list.


The cow-number Excel file is **not**:

```text
Alpro Cow Number → DairySense Cow Number
```

It is only a list of cow numbers that should be included.

Example:

```text
Alpro HTML:
5
8
12
15
20
31
44
...

Current DairySense Cow List:
5
12
20
31
44
...

Output:
Only Alpro records for:
5, 12, 20, 31, 44, ...
```

The cow number itself is the matching key. The row order is irrelevant.

---

## 3. Current Cow List Lifecycle

The current cow list changes over time.

### New list supplied

When the user imports a new cow-list Excel:

1. Validate it.
2. Extract cow numbers.
3. Save it locally.
4. Replace the previous current list.
5. Use the new list for the current conversion.

A failed/invalid update must **never destroy the previous valid list**.

### No new list supplied

If a previous valid list exists, use it automatically.

Therefore:

```text
New list supplied
    → validate
    → save
    → use newest list

No new list
    → use last saved list
```

### First use

If no list has ever been saved and the user attempts conversion without one:

- Do not export all Alpro records.
- Explain that a cow list is required.
- Ask the user to import one.

---

## 4. Missing Selected Cows

If a cow number exists in the current DairySense list but does not exist in the Alpro HTML:

- Detect it.
- Show the missing cow numbers.
- Ask the user before continuing.

Example:

```text
Some selected cows were not found in the Alpro report.

Missing:
44

[ Cancel ] [ Continue ]
```

Rules:

- Cancel → no output is generated.
- Continue → export the cows that were found.
- Never create fake rows.
- Never silently ignore missing selected cows.

---

## 5. Input: Alpro HTML

The supplied Alpro reports contain approximately 147 records per session
(real: Session1=147, Session2=127, Session3=140).

Relevant fields identified so far:

- `Cow No.`
- `Group No.`
- `Transp. No.`
- `Milk Yield`
- `Corrected Yield`
- `ID Time`
- `Milk Start Time`
- `Milk Dur.`
- `MPC Address`
- `Storage Position`

The parser should use the HTML structure and column names rather than fragile regex/position assumptions.

Required behavior:

- Parse the HTML document.
- Locate the relevant table.
- Identify columns by their headers.
- Normalize values.
- Validate required fields.
- Produce domain records independent of Flutter UI.

---

## 6. Input: Cow-Number Excel

The cow-number Excel is the filter list.

Conceptually:

```text
Cow Number
-----------
5
12
20
31
44
...
```

Requirements:

- Read cow numbers.
- Ignore blank rows.
- Detect invalid values.
- Normalize values consistently with Alpro `Cow No.`.
- Deduplicate internally.
- Preserve numeric identity.
- Do not interpret the list as a mapping.

The exact sample workbook structure should be inspected during Spec Kit research.

---

## 7. Output: DairySense Excel

The generated workbook must follow the supplied DairySense import format.

Required columns:

| Output Column | Rule |
|---|---|
| `Date` | Date from Alpro report |
| `Session` | Session from Alpro report |
| `UnitNo` | Alpro `MPC Address` |
| `CowNumber` | Alpro `Cow No.` |
| `Milking Time` | Alpro `Milk Dur.` converted to seconds |
| `Milk yield` | Alpro `Milk Yield` |
| `Conductivity` | Always `0` |
| `temperature` | Always `0` |

The exact workbook structure, sheet name, data types, and formatting should be verified against the supplied DairySense template during planning.

---

## 8. Transformation Rules

### CowNumber

```text
Alpro.Cow No. → DairySense.CowNumber
```

### Milk yield

```text
Alpro.Milk Yield → DairySense.Milk yield
```

### UnitNo

```text
Alpro.MPC Address → DairySense.UnitNo
```

### Milking Time

Convert `Milk Dur.` from `HH:MM:SS` into total seconds.

Example:

```text
00:03:00 → 180
```

Formula:

```text
hours × 3600 + minutes × 60 + seconds
```

Missing/invalid duration must be handled gracefully and specified before
implementation.

**\[decided\]** A *truly empty* yield/dur cell is skipped with a warning; a
*non-empty* non-numeric yield or non-time duration (`-`, a cow not milked that
session) is kept and exported as `0` (`milkYield = 0.0`, `milkingTime = 0`).

### Conductivity

Always:

```text
0
```

### temperature

Always:

```text
0
```

### Date

Extract from the Alpro report. Do not use the computer's current date.

### Session

Extract from the Alpro report. Do not hard-code `Session 1` if the report can contain another session.

---

## 9. Complete Conversion Workflow

```text
Select Alpro HTML
        ↓
Parse HTML
        ↓
Load saved current cow list
        ↓
Optionally import new cow list
        ↓
Validate and save new list if supplied
        ↓
Filter Alpro records by Cow No.
        ↓
Detect selected cows missing from Alpro
        ↓
Ask user whether to continue if any are missing
        ↓
Transform matching records
        ↓
Validate output data
        ↓
Create DairySense XLSX
        ↓
Ask user for output folder
        ↓
Save XLSX
        ↓
Show conversion summary
```

Do not partially create the final workbook before validation is complete.

---

## 10. Output Folder

The destination folder must be selected by the user **every time**.

Do not silently use Downloads, Desktop, Documents, or the application folder.

Suggested filename:

```text
DairySense_Import_YYYY-MM-DD.xlsx
```

**\[decided\]** Final default (editable in the native save dialog, chosen every
time): 12-hour `DairySense_Import_<YYYY-MM-DD>_<H.mm am/pm>.xlsx` (e.g.
`DairySense_Import_2026-08-10_11.13 am.xlsx`). A write failure (existing/locked
file) shows a friendly message and re-opens the dialog to retry; cancelling the
dialog resets the UI with no file created.

---

## 11. UI Requirements

The initial Windows UI should be simple.

Suggested main screen:

```text
┌──────────────────────────────────────────────┐
│          ALPRO → DAIRYSENSE                  │
│                                              │
│ Alpro HTML                                   │
│ [ Select HTML File ]                         │
│                                              │
│ Current Cow List                             │
│ ✓ the current set of cows loaded                             │
│ Last updated: <date/time>                    │
│ [ Update Cow List ]                          │
│                                              │
│              [ CONVERT ]                     │
│                                              │
│ Status                                       │
│ Alpro records:       147                     │
│ Selected cows:        <count>                     │
│ Found:                <count>                     │
│ Missing:               <count>                     │
└──────────────────────────────────────────────┘
```

The UI must make clear:

- Which HTML is selected.
- Which cow list is currently active.
- When the list was last updated.
- Whether the list was loaded from saved data.
- How many records were found/missing.

---

## 12. Architecture

Clean architecture mirroring the `Uni` reference repo (feature-first,
flutter_bloc + dartz). Keep UI and conversion logic separate. Dependencies
point inward: `main.dart` → `features/*/presentation` →
`features/*/domain` → `features/*/data` → `core/`.

```text
lib/
├── main.dart                       # entry + shared MainScreen shell (composition root)
├── core/                           # shared, framework-independent
│   ├── errors/
│   │   ├── failures.dart           # Failure base + typed failures (dartz Either)
│   │   └── custom_exceptions.dart  # thrown typed errors (AlproParseError, CowListError, ...)
│   ├── helper_functions/           # error_dialog, file_picker_helper, show_conversion_summary
│   └── utils/app_utils.dart        # normalizeHeader, normalizeCowNumber, durationToSeconds
└── features/
    ├── home/                       # Alpro → DairySense pipeline
    │   ├── data/
    │   │   ├── data_sources/       #   alpro_parser.dart, dairy_sense_writer.dart (+ classes)
    │   │   └── repos/conversion_repo_impl.dart  # implements repo → Either<Failure,T>
    │   ├── domain/
    │   │   ├── entities/           #   alpro_record, alpro_report, cow_list, dairy_sense_row, conversion_result
    │   │   ├── repos/conversion_repo.dart      #   abstract boundary (Either<Failure,T>)
    │   │   └── use_cases/          #   filter_records, detect_missing_cows, build_dairy_sense_rows, convert_report
    │   └── presentation/
    │       ├── manager/conversion_cubit/  #   cubit + part state (Initial/Loading/Success/Failure)
    │       └── views/              #   main_screen.dart + widgets/ (cow_list_card, report_convert_view)
    └── cow_list/                   # cow list management (US2, not yet implemented)
```

### Presentation

- Main screen
- File pickers
- Folder picker
- Missing-cow confirmation
- Errors
- Status/progress
- Conversion summary
- State managed by a **flutter_bloc Cubit** (`ConversionCubit`), read via
  `BlocBuilder` / `BlocListener`.

### Domain

Entities (feature-scoped under `features/home/domain/entities/`):

- `AlproRecord`
- `AlproReport`
- `CowList`
- `DairySenseRow`
- `ConversionResult`

### Application / Use Cases

Thin use-case classes wrapping the abstract `ConversionRepo`
(`features/home/domain/use_cases/`):

- `FilterRecordsUseCase` — filter Alpro records by cow list
- `DetectMissingCowsUseCase` — detect selected cows absent from the report
- `BuildDairySenseRowsUseCase` — map/transform matched records
- `ConvertReportUseCase` — orchestrator; guards no-cow-list, delegates to repo

### Infrastructure

- HTML parser (`AlproParser`)
- Excel reader
- Excel writer (`DairySenseWriter`)
- Local persistence
- File/folder picker

### Error handling

The data layer (`ConversionRepoImpl`) catches thrown
`custom_exceptions.dart` and maps them to `dartz.Either<Failure, T>` using the
typed failures in `core/errors/failures.dart`. The UI shows the `Failure.message`
— never a raw stack trace.

Package choices: `html`, `excel`, `file_picker`, `path_provider`, `path`,
plus `flutter_bloc` and `dartz` (for the Uni-pattern state + failure modeling).

---

## 13. Flutter / Windows Direction

Target:

- Flutter
- Dart
- Windows desktop first

Likely technical areas:

- HTML parsing
- XLSX reading
- XLSX generation
- Windows file/folder dialogs
- Local persistence

Use maintained packages compatible with the project's Flutter/Dart version.

Avoid unnecessary dependencies.

---

## 14. Persistence

Persist locally:

```text
Current cow numbers
Last updated timestamp
```

The data must survive application restarts and Windows reboots.

No remote database is required.

---

## 15. Validation and Error Handling

### Invalid Alpro file

Show a user-friendly message if the file is not a valid Alpro report.

### Missing required columns

At minimum, validate the fields required to generate the DairySense output.

### Invalid cow-list Excel

- Reject the new list.
- Keep the previous valid list.
- Explain the problem.

### Duplicate cows

Deduplicate internally and optionally warn.

### Missing selected cows

Ask the user whether to continue.

### Output errors

Handle:

- permission denied
- invalid destination
- output file already open
- existing file
- filename problems

Never expose raw stack traces as the primary user message.

---

## 16. Testing Strategy

### Unit tests

Cover (implemented in `test/alpro_parser_test.dart` and `test/converter_test.dart`):

1. Alpro HTML parsing.
2. Header detection.
3. Cow-number normalization.
4. Cow filtering (`FilterRecordsUseCase`).
5. Missing-cow detection (`DetectMissingCowsUseCase`).
6. Duration conversion.
7. Output field mapping (`BuildDairySenseRowsUseCase`).
8. Conductivity = 0.
9. temperature = 0.
10. Duplicate handling.
11. Invalid values.
12. Cow-list persistence.

### Integration test

Use the supplied files:

```text
Alpro HTML (real: Session1/Session2/session3 reports)
+
Cow-number Excel
↓
DairySense XLSX
```

Verify:

- number of output rows
- exported cow numbers
- milk yields
- unit numbers
- milking-time seconds
- conductivity values
- temperature values
- column order

Keep the supplied files as regression fixtures. The integration test MUST skip
gracefully when the fixture files are absent (see T021).

---

## 17. Performance

The current example contains about 147 records, but the application should not impose an artificial 147-record limit.

Target comfortable processing of several thousand records.

Avoid freezing the Windows UI during expensive parsing or workbook generation.

---

## 18. Non-Goals for MVP

Do not implement:

- Alpro modification.
- DairySense modification.
- Cloud synchronization.
- Login/account system.
- Cloud database.
- Automatic herd synchronization.
- Alpro-to-DairySense number mapping.
- Automatic output folder selection.
- Fake conductivity/temperature values.
- Manual mapping configuration.

---

## 19. Future Extensibility

Leave room for:

- Other Alpro report formats.
- Other DairySense import formats.
- Multiple farm profiles.
- Multiple saved cow lists.
- Configurable output mappings.
- Additional Alpro measurements.
- Preview before export.
- Conversion history.

These are not MVP requirements.

---

## 20. MVP Definition of Done

MVP is complete when the user can:

- Run the Windows Flutter application.
- Select an Alpro HTML report.
- Import/update the current DairySense cow list.
- Reuse the last saved cow list automatically.
- Filter Alpro records by `Cow No.`.
- Detect missing selected cows.
- Confirm whether to continue.
- Generate the DairySense Excel format.
- Produce:
  - Date
  - Session
  - UnitNo
  - CowNumber
  - Milking Time
  - Milk yield
  - Conductivity = 0
  - temperature = 0
- Choose the output folder every time.
- Restart the application without losing the current cow list.
- Pass automated tests for the core conversion pipeline.

---

## 21. Acceptance Scenarios

### A. New cow list

Given an Alpro report with 147 cows and a new cow list containing the current set of cows:

- only matching Alpro records are exported;
- the new list becomes the saved current list.

### B. Reuse previous list

Given a previously saved cow list and no new list:

- the saved list is automatically used.

### C. Replace list

Given a saved list and a new valid list:

- the new list replaces the old list;
- the old list remains untouched if validation fails.

### D. Missing cow

Given a cow in the current list that is absent from Alpro:

- show the missing cow;
- ask whether to continue;
- Cancel produces no output;
- Continue exports only found cows.

### E. Output folder

After successful conversion:

- always ask the user for a destination folder;
- save the generated workbook there.

All acceptance scenarios A–E are implemented (see Phase 3–6 in `tasks.md`).

---

## 22. Open Questions for Spec Kit Clarification

These should be resolved before the final implementation plan.

**\[decided\]** (confirmed by real files / implementation):
- Cow-number column: auto-detected (`Cow Number` header, fallback to first numeric column).
- Date format: pass-through of the Alpro Date token (e.g. `26.08.08`), not the computer's date.
- Sessions: extracted from the report title "Session N" → `1`/`2`/`3`, not hard-coded to Session 1.
- Missing/invalid `Milk Dur.`/`Milk Yield`: truly empty → skipped with warning; dry-cow `-` → kept and exported as `0`.
- Output filename: `DairySense_Import_<YYYY-MM-DD>_<H.mm am/pm>.xlsx` (12-hour, editable).

Still open / non-MVP:
- Cow numbers are integers (assumed; normalization trims/parses — leading-zero IDs not needed).
- Exact sheet name / multiple sheets (single sheet, 8 fixed headers; verify against template when available).
- Drag-and-drop and a full filtered-record preview are not in MVP scope.

---

## 23. Suggested Feature Structure

Feature name:

```text
alpro-dairysense-converter
```

Implementation phases (aligned to the plan in `specs/001-alpro-dairysense-converter/plan.md`):

### Phase 1 — Foundation
- Flutter Windows project
- Architecture (Uni pattern: feature-first, flutter_bloc + dartz)
- `core/errors/` (failures + custom exceptions), `core/utils/app_utils.dart`
- `features/home/domain/entities/` (AlproRecord, AlproReport, CowList, DairySenseRow, ConversionResult)
- Error handling foundation

### Phase 2 — Alpro Parser
- HTML loading
- Table detection
- Header detection
- Alpro model
- Validation
- `features/home/data/data_sources/alpro_parser.dart`

### Phase 3 — Cow List Management
- Excel import
- Cow-number extraction
- Validation
- Local persistence
- Replace current list
- Last-updated information
- `features/cow_list/`

### Phase 4 — Filtering and Transformation
- Cow filtering
- Missing-cow detection
- Confirmation dialog
- Field transformation
- Duration conversion
- Default measurement values
- `features/home/domain/use_cases/` + `data/repos/conversion_repo_impl.dart`

### Phase 5 — DairySense Excel
- Workbook creation
- Exact columns/order
- Correct data types
- Output filename
- Folder picker
- `features/home/data/data_sources/dairy_sense_writer.dart`

### Phase 6 — UI, State, and Polish
- `ConversionCubit` (flutter_bloc) + `features/home/presentation/`
- Unit tests
- Integration tests
- Error states
- Status UI
- Conversion summary
- Windows packaging

---

## 24. Core Design Principle

Do not build the UI first and then force the conversion logic into it.

The core application should be a deterministic pipeline, implemented as pure
use cases in `features/home/domain/use_cases/` (with IO in the data layer):

```text
ALPRO HTML
    ↓
Parse (AlproParser)
    ↓
Validate
    ↓
Current Cow List
    ↓
Filter (FilterRecordsUseCase)
    ↓
Detect Missing (DetectMissingCowsUseCase)
    ↓
Transform (BuildDairySenseRowsUseCase)
    ↓
Validate Output
    ↓
DairySense XLSX (DairySenseWriter)
```

This pipeline must be independently testable without Flutter UI. It is exposed
to the UI through `ConversionRepo` → `ConvertReportUseCase` → `ConversionCubit`,
returning `Either<Failure, ConversionResult>`.

The Flutter UI should orchestrate the pipeline and present status, warnings,
confirmations, and results.

---

## 25. Source Files

The project should use the supplied real files as fixtures/reference material:

- Alpro HTML reports (three sessions: `Session1 8-8.htm.html`,
  `Session2 7-8.htm.html`, `session 3 7-8.htm.html`).
- DairySense import Excel template.
- Current DairySense cow-number Excel list.

The implementation must inspect the actual files and must not invent their
structure. The Alpro reports have been inspected and the parser verified
against them (prefix header matching, dry-cow handling, real Date/Session
extraction); the cow-list and template files are still to be copied into
`test/fixtures/` for the integration test.

---

## 26. Definition of Done

The project is done when:

- Windows build succeeds.
- Supplied Alpro HTML parses correctly.
- Supplied cow list imports correctly.
- Only requested cows are exported.
- Missing cows require confirmation.
- Latest valid cow list persists.
- New valid list replaces the old one.
- Failed list update preserves the old list.
- DairySense workbook structure is correct.
- Conductivity = 0.
- temperature = 0.
- Milk duration converts correctly to seconds.
- Output folder is selected every time.
- Invalid input does not crash the app.
- Automated tests cover the transformation rules.
- End-to-end conversion passes using the supplied sample files.
