# Alpro → DairySense Milk Data Converter

> **Implementation status (2026-08-14):** **Released as v1.0.0** (tag
> `v1.0.0`). All phases 1–7 of the Spec Kit plan are implemented and verified
> (US1–US4 plus integration/performance/polish). The real Alpro reports
> (`Session1 8-8`, `Session2 7-8`, `session 3 7-8`) parse and convert
> end-to-end (147 / 127 / 140 records; Date `26.08.08`; Session `1/2/3`; dry
> cows → `0`). All 27 tasks in `tasks.md` are done; `flutter analyze` clean;
> `flutter test` green (52 unit + integration tests); `flutter build windows`
> succeeds; manual acceptance (quickstart §4 cases A–G) passed; generated
> files verified to import into real DairySense. No implementation work
> remains. See `tasks.md` (authoritative) and the Spec Kit under
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
structure. All three real files are inspected and verified against, and are
shipped as regression fixtures in `test/fixtures/` (`alpro_report.html`,
`current_cow_list.xlsx`, `dairy_sense_template.xlsx`); the integration test
runs end-to-end on them.

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

---
---

# PART 2 — v1.1 "Alfa Milk Pro" Extension Plan

> **Status (2026-08-14):** Planning. v1.0.0 is released, stable, and tagged
> (`v1.0.0`, pushed to origin). Everything in Part 1 above is **historical —
> do not edit it**; it documents what shipped in v1.0.0. This Part 2 is the
> **new, additive plan** for the next release, tentatively `v1.1.0`
> ("Alfa Milk Pro"). Nothing in Part 1 is being removed or redesigned —
> v1.1 builds on top of the same Clean Architecture, same pipeline, same
> business rules (§2 and §5 of Part 1 still apply in full, including "cow
> list is a filter, not a mapping").

## 27. Why v1.1

v1.0.0 proved the core conversion pipeline works and is trusted with real
farm data. The daily pain point that emerged from actual use is **repetition**:
the user runs the same Alpro→XLSX conversion 3+ times per day (once per
milking session) and then re-does a manual multi-step import into a separate
Windows tool (`MilkIntegration.exe`) for each resulting file. v1.1 targets
that repetition directly, plus distribution/security concerns now that the
app is going to run on a machine the developer does not personally control
every day.

## 28. v1.1 Feature List (13 items, grouped)

All 13 items below were agreed with the user. Nothing here breaks or
contradicts the v1.0 business rules in §2/§5 (Part 1); the cow list is still
a filter, cow count is still unbounded, Conductivity/temperature are still
`0`, output folder is still chosen every time (or superseded by the new
auto-import flow — see §30.2), etc.

### Group A — Core time-saver (P1, build first)
1. **Multi-session merge**: accept any number of Alpro HTML files (one per
   milking session — today usually 3/day) in a single conversion and produce
   **one** DairySense XLSX containing all of them, instead of converting and
   importing each session file separately.
2. **One-click DairySense import**: after the merged XLSX is produced, a
   single in-app button drives `MilkIntegration.exe` end-to-end (open →
   click "Load Milk Data" → pick the generated file → read the result dialog)
   and reports success/failure back inside Alfa Milk, with no manual window
   switching.

### Group B — Supporting UX for Group A (P1, ships alongside A)
3. **Drag & drop** of one or many `.html` report files (in addition to the
   existing multi-select file picker).
4. **Live progress panel** (replacing the current blocking spinner):
   streams what the pipeline is doing right now ("Parsed Session 2 — 127
   records", "Filtering by cow list…", "Writing workbook…") and — merged
   with the old "preview before export" idea — also shows the record/cow
   counts that will actually be exported before final confirmation.
5. **Implausible cow-number warning**: flag (not block) any parsed cow
   number outside a sane range (e.g. absurdly large / clearly a typo) as a
   soft warning in the live panel and the summary, to catch data-entry
   mistakes early. Never silently drops or "corrects" the number.

### Group C — Records & safety (P2)
6. **Conversion History**: every completed conversion is logged (timestamp,
   number of source session files, session numbers/dates, record count,
   output filename) and the generated XLSX itself is retained so it can be
   re-downloaded or re-imported later without redoing the conversion.
7. **Delete from History**: the user can remove old entries (and their
   retained files) from inside the app.
8. **Export History** to Excel or PDF, for sharing a record of past
   conversions outside the app.
9. **Automatic cow-list backup**: every time the active cow list is
   replaced, the previous version is retained (not just overwritten), so a
   bad update can be rolled back.

### Group D — Distribution & protection (P2)
10. **Professional installer** (Windows `.exe`/`.msix`) replacing "just copy
    the build folder" — Start Menu entry, uninstaller, versioned.
11. **Hardware-locked licensing**: the app binds itself to the machine it is
    first installed on (machine fingerprint) and refuses to run if copied
    elsewhere; the developer issues a license/activation per machine.

### Group E — Look & feel polish (P3, last)
12. **UI redesign**: clean, professional, agriculture-appropriate visual
    identity — built *after* the functional features above, once the new
    screens (multi-file, live panel, history, dashboard) exist to design
    around.
13. **Dashboard home screen**: last conversion summary, active cow-list
    count, and a staleness warning if the cow list hasn't been updated in
    ~30 days.
14. **Dark mode.**

### Explicitly rejected for v1.1 (asked about, declined by the user)
- ❌ Cloud sync / login / remote database — contradicts the local-first,
  offline, no-network constitution principle (Part 1 §I); no stated need.
- ❌ Alpro↔DairySense cow-number mapping — confirmed still not needed; the
  cow list remains a pure filter (Part 1 §2, non-negotiable).
- ❌ Multiple farms / multiple saved cow lists — single farm only, now and
  for the foreseeable future.

## 29. DairySense Import Automation — Confirmed Target (`MilkIntegration.exe`)

Investigated directly (screenshots supplied 2026-08-14). This is a small,
static internal Windows tool, not DairySense itself — it is the bridge
DairySense support already uses for importing milk data. It is simple and
stable, which makes UI Automation the right approach (not OCR, not
coordinate-clicking).

- **Location**: `C:\Program Files (x86)\Dairysense Herd Management\Debug\MilkIntegration.exe`
- **Window title**: "Milk importer v0.1"
- **UI**: one window, one button — **"Load Milk Data"**.
- **Flow**:
  1. Launch (if not already running) → window "Milk importer v0.1" appears.
  2. Click **Load Milk Data**.
  3. A **standard Windows "İçe aktarılacak dosyayi seçin" (Open) dialog**
     appears (native `GetOpenFileName`-style dialog, filter "Excel Dosyaları
     (*.xlsx;*.xls)") — not a custom-drawn dialog, which is good for
     automation reliability.
  4. Type/set the generated `.xlsx` path into the "File name" field, click
     **Open**.
  5. A result `MessageBox` appears:
     - Success → title **"Tamam"**, icon ℹ️, text pattern `"<N> kayıt
       başarıyla yüklendi."` (Turkish: "N records loaded successfully.").
       Button: OK.
     - Failure → title **"Hata"**, icon ❌, text is the error detail (e.g.
       `"Hata: Subquery returns more than 1 row"` seen in testing). Button: OK.
     - **Rule of thumb (user-confirmed): any dialog title other than
       "Tamam" is a failure** — treat generically rather than hardcoding a
       string allowlist of error text.
  6. Click OK to dismiss the result dialog.

- **Automation approach**: Windows UI Automation (e.g. via `FlaUI` or the
  raw `UIAutomation` COM API from a small Dart FFI/native helper, or a
  bundled .NET helper process) — find window by title, find button by
  `AutomationId`/name, invoke it; find the Open dialog by class
  (`#32770`), set the filename edit control, invoke "Open"/press Enter;
  wait for a new top-level dialog matching "Tamam" or "Hata" (or any
  unexpected title, per the rule above), read its static text, click OK.
  All waits are event/poll-based with a sane timeout (e.g. 15s) rather than
  fixed sleeps, and any timeout is surfaced to the user as its own error
  state rather than hanging.
- **Risk (acknowledged, accepted by user)**: this is coupling to an
  external app's UI. If `MilkIntegration.exe` is ever updated, automation
  may break. Because the tool is small/internal and rarely changes, this
  risk was accepted rather than falling back to "just open the app for the
  user." Mitigation: fail loud and clear (never silently "look" successful),
  and keep a manual fallback (open `MilkIntegration.exe` and let the user do
  it by hand) always available as a backup path in the UI.
- **Not yet confirmed / to verify during implementation**: exact
  `AutomationId`s of the button/dialog controls (to be inspected with a
  tool like `FlaUI Inspect` / Accessibility Insights once implementation
  starts); whether multiple `MilkIntegration.exe` instances can coexist;
  behavior if DairySense's own main app is also open at the same time.

## 30. New / Changed Business Rules for v1.1

These are additive to Part 1 §5 (Core Business Rules), not replacements.

1. **Multi-file input is still filtered by the same single cow list.** The
   cow list remains one active filter list, applied uniformly across every
   session file in the batch — no per-file cow lists.
2. **Merged output is one workbook, one sheet, same 8 columns**, sorted in a
   defined, deterministic order (default: by report Date then Session, then
   original row order within a session) — never silently interleaved in an
   unpredictable way. *(Open question — see §33.)*
3. **Missing-cow detection now spans all input files together**: a selected
   cow is only "missing" if absent from *every* session in the batch, not
   just one. The confirm dialog lists cows missing from the whole batch,
   once.
4. **Duplicate/overlapping session detection**: if two input files resolve
   to the same (Date, Session) pair, warn the user before merging (does not
   block by default — user can still proceed) *(open question — see §33)*.
5. **Auto-import never replaces the "ask every time" save step**; it is an
   additional step *after* the XLSX is saved to disk normally (Part 1 FR-015
   still applies in full — the merged file is still saved to a
   user-chosen folder first). Auto-import reads that same saved file.
6. **History never silently deletes.** Retained generated files persist
   until the user explicitly deletes the History entry; nothing is
   auto-purged (no default TTL) in v1.1.
7. **Cow-list backup is automatic and silent** (no extra user action) but
   restoring a previous version is an explicit user action, never automatic.
8. **License/hardware lock never destroys data.** A license failure blocks
   the app from running conversions but must never delete the local cow
   list, history, or `.xlsx` output already on disk.

## 31. Architecture Additions

Extends the existing feature-first Clean Architecture (Part 1 §12); no
existing feature module is restructured.

```text
lib/
├── features/
│   ├── home/                       # existing (v1.0) — Alpro→DairySense pipeline
│   │   ├── data/data_sources/      # alpro_parser.dart, dairy_sense_writer.dart
│   │   │                           #   → parser/writer extended to accept
│   │   │                           #     List<String> htmlPaths (multi-file)
│   │   ├── domain/use_cases/       # + MergeReportsUseCase (new)
│   │   └── presentation/           # + live progress panel, drag&drop dropzone
│   ├── cow_list/                   # existing — + backup-on-save behavior
│   ├── dairysense_import/          # NEW feature module
│   │   ├── data/                   #   windows_ui_automation_client (FFI/process bridge)
│   │   ├── domain/                 #   ImportResult, RunDairySenseImportUseCase
│   │   └── presentation/           #   "Import to DairySense" button + result dialog
│   ├── history/                    # NEW feature module
│   │   ├── data/                   #   history_store.dart (JSON index) + retained-files dir
│   │   ├── domain/                 #   ConversionHistoryEntry, use_cases (list/delete/export)
│   │   └── presentation/           #   history_screen.dart (list, download, delete, export)
│   ├── licensing/                  # NEW feature module
│   │   ├── data/                   #   machine_fingerprint.dart, license_store.dart
│   │   ├── domain/                 #   LicenseStatus, ValidateLicenseUseCase
│   │   └── presentation/           #   activation/blocked screen (shown before MainScreen)
│   └── dashboard/                  # NEW feature module (replaces plain MainScreen entry)
│       └── presentation/           #   dashboard_screen.dart (last conversion, cow-list age, etc.)
├── core/
│   └── theme/                      # NEW — design tokens for the UI redesign + dark mode
```

- **Multi-file merge** lives inside the existing `home` feature (it's a
  variant of the same pipeline, not a new domain), reusing
  `FilterRecordsUseCase` / `DetectMissingCowsUseCase` /
  `BuildDairySenseRowsUseCase` unchanged — only the parse step becomes "parse
  N files, concatenate `AlproRecord`s with their source Date/Session before
  filtering."
- **DairySense import automation** is isolated in its own feature/module
  specifically because it's an OS-level integration with a different failure
  mode (external process, timeouts, window-not-found) than the rest of the
  app, which is pure file IO. Keeping it isolated means a break here can
  never take down the core conversion pipeline.
- **Licensing** is checked at app startup, before `MainScreen`/`Dashboard`
  is reachable, as its own gate screen.

## 32. Proposed Phases for v1.1 (priority-ordered per user's explicit choice)

User's stated priority: **"time-savers first"** — merge + auto-import,
because they save real daily time; polish/UI last.

### Phase A — Multi-session merge (Group A.1)
- Extend `alpro_parser.dart` to accept multiple HTML file paths, tag each
  parsed record's source session, and merge into one `AlproReport`-like
  aggregate before filtering/writing.
- Update `dairy_sense_writer.dart` / writer flow: unchanged output format
  (still 8 columns, `Sayfa1`), just more rows from more sources.
- Update missing-cow detection to span the whole batch (§30.3).
- Tests: unit tests for the merge/aggregation step; a synthetic 3-file
  merge test asserting row count = sum of per-file matches and correct
  Date/Session per row.

### Phase B — DairySense one-click import (Group A.2)
- New `dairysense_import` feature module (§31).
- Implement the UI Automation client against the confirmed flow (§29).
- Manual fallback button ("Open MilkIntegration.exe manually") always
  visible next to the automated one.
- Tests: cannot be fully automated without the real exe in CI — plan for a
  manual test checklist (quickstart-style) plus any unit tests possible
  around the result-parsing logic (e.g. parsing "N kayıt başarıyla
  yüklendi." → success count) in isolation.

### Phase C — Supporting UX (Group B)
- Drag & drop (`desktop_drop` or equivalent).
- Live progress panel + merged preview-before-export.
- Implausible-cow-number soft warning.
- These naturally piggyback on Phase A's new multi-file flow.

### Phase D — History & data safety (Group C)
- `history` feature module: log entry per conversion, retained file storage,
  list/download/delete UI.
- History export (Excel/PDF).
- Cow-list automatic backup-on-replace.

### Phase E — Distribution & protection (Group D)
- Installer packaging (Inno Setup or MSIX).
- `licensing` feature module: machine fingerprint, activation gate,
  license issuance process (developer-side tooling, not just in-app).

### Phase F — Look & feel (Group E, last, per user priority)
- Design tokens / theme rework for a clean, professional, agriculture-
  appropriate look.
- Dashboard home screen.
- Dark mode.

## 33. Open Questions for v1.1 (to resolve before/at start of each phase)

1. **Merged-row ordering** (§30.2): confirm default sort — by Date+Session,
   or strictly by the order files were added/dropped?
2. **Duplicate (Date, Session) across two input files** (§30.4): warn-and-
   allow (default assumed) or hard-block?
3. **`MilkIntegration.exe` control identifiers**: exact `AutomationId`s /
   class names for the button and dialogs — to be captured with an
   inspector tool at the start of Phase B.
4. **License issuance workflow**: how does the developer generate/deliver a
   license key per machine in practice (manual email exchange, a small
   companion CLI, etc.)? Needs a concrete process, not just the in-app
   validation side.
5. **History retention limits**: no TTL/auto-purge in v1.1 (§30.6) — confirm
   this remains fine even after months of daily use (disk usage growth of
   retained `.xlsx` files), or whether a manual "clear old entries" bulk
   action should be added later.

## 34. Non-Goals for v1.1 (reaffirmed / new)

Carried over from Part 1 §10, still non-goals: modifying Alpro/DairySense
itself, cloud sync/login/database, herd sync, Alpro↔DairySense number
mapping, invented conductivity/temperature values, manual mapping config.

Newly declined for v1.1 specifically (§28, "Explicitly rejected"):
multiple farms / multiple cow lists.

## 35. Definition of Done for v1.1

- User can drag/select any number of Alpro HTML session files and get one
  merged DairySense XLSX, sorted deterministically, with all v1.0 business
  rules (filter-not-mapping, missing-cow confirmation spanning the batch,
  no fake rows, Conductivity/temperature = 0, folder chosen every time)
  still holding.
- User can click one button after saving the merged file and have it
  imported into DairySense via `MilkIntegration.exe` automatically, with a
  clear success/failure result shown in Alfa Milk — and a manual fallback
  always available if automation fails.
- Every conversion appears in History with enough detail to identify it
  later, is re-downloadable, and is deletable; History is exportable.
- Cow-list updates are automatically backed up before being replaced.
- The app ships as a proper Windows installer and refuses to run on a
  machine it wasn't licensed/activated for, without ever destroying local
  data if the license check fails.
- The UI has been redesigned (clean, professional, agricultural) with a
  working dashboard and dark mode, built around the finished functional
  features above — not before them.