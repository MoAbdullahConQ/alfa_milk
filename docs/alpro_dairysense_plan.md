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
>
> **Structure (revised 2026-08-31; release order revised 2026-09-02):** Part 2 was
> first written as a single
> release containing 14 features under one shared Definition of Done. It is now
> organised as **eight independently shippable releases (v1.1.0 – v1.8.0) plus
> one non-shippable spike**, each with its own goal, scope and DoD (§32).
> On 2026-09-02 the licensing release was moved from second to **seventh**
> (Phase 7 / `v1.7.0`), so every time-saving feature ships before the hardware
> lock; the accepted consequence and its mitigation are recorded in §32 and
> §30.17.
> Nothing from the original Part 2 has been dropped: **§36** traces every
> original §28 feature, §30 rule, §31 module, §33 question and §34 non-goal to
> where it now lives (kept / redesigned / deferred), and **§37** carries the
> defect register raised by reviewing this plan against the shipped v1.0 code.
> Section numbers §27–§35 are unchanged so existing cross-references still
> resolve.

## 27. Why v1.1

v1.0.0 proved the core conversion pipeline works and is trusted with real
farm data. The daily pain point that emerged from actual use is **repetition**:
the user runs the same Alpro→XLSX conversion 3+ times per day (once per
milking session) and then re-does a manual multi-step import into a separate
Windows tool (`MilkIntegration.exe`) for each resulting file. v1.1 targets
that repetition directly, plus distribution/security concerns now that the
app is going to run on a machine the developer does not personally control
every day.

### 27.1 Why this ships as eight releases, not one

The original Part 2 planned all 14 features as a single `v1.1.0` with a single
Definition of Done (§35). Three things force a split:

- **A 14-feature release has no testable DoD.** "Done" for merge, automation,
  history, an installer, licensing and a redesign cannot be observed in one
  pass; a failure in any one blocks shipping all of the others.
- **Licensing must not ship before the data root.** A hard licence lockout
  (§30.14) is only survivable because uninstalling, reinstalling and
  reactivating restores the farm's cow list and history untouched. That
  requires the fixed `%ProgramData%` location (§30.15) to exist *first* — so
  distribution and data durability are release one, and licensing cannot be
  scheduled before it. Licensing is in fact release **seven**, deliberately
  placed after every time-saving feature (§32) and defused for the machines
  already running unlicensed by §30.17.
- **Two features are gated on facts nobody has yet.** Multi-session merge
  depends on whether real DairySense accepts a workbook spanning two dates
  (acceptance cases H–K, §33.5); the import automation depends on what the
  real `MilkIntegration.exe` window actually exposes (§29.7). Neither can be
  scheduled honestly as if the answer were known.

The result is eight independently shippable releases plus one non-shippable
spike (§32), ordered so each one is useful on its own and none depends on a
later one.

## 28. v1.1 Feature List (14 items, grouped)

All 14 items below were agreed with the user. Nothing here breaks or
contradicts the v1.0 business rules in §2/§5 (Part 1); the cow list is still
a filter, cow count is still unbounded, Conductivity/temperature are still
`0`, output folder is still chosen every time (auto-import is an additional
step *after* that save, never a replacement for it — see §30.5).

Each item carries a **→** line recording its disposition and the release that
delivers it. §36 is the full traceability table; nothing is dropped without
appearing there.

### Group A — Core time-saver (P1, build first)
1. **Multi-session merge**: accept any number of Alpro HTML files (one per
   milking session — today usually 3/day) in a single conversion and produce
   **one** DairySense XLSX containing all of them, instead of converting and
   importing each session file separately.
   → **Kept, design corrected** (§31.2: convert per report, concatenate rows —
   not "concatenate records before filtering", which destroys per-row
   Date/Session provenance). **Phase 2 / v1.2.0**, gated on §33.5 (cases H–K).
2. **One-click DairySense import**: after the merged XLSX is produced, a
   single in-app button drives `MilkIntegration.exe` end-to-end (open →
   click "Load Milk Data" → pick the generated file → read the result dialog)
   and reports success/failure back inside Alfa Milk, with no manual window
   switching.
   → **Kept, re-architected in-process** (§29.4 Dart FFI, no helper
   executable) with a four-outcome result taxonomy (§29.5) instead of
   success/failure. **Phase 5 / v1.5.0**, after the ledger that makes an
   unreadable outcome recoverable (Phase 4) and after the spike (Phase 5S).

### Group B — Supporting UX for Group A (P1, ships alongside A)
3. **Drag & drop** of one or many `.html` report files (in addition to the
   existing multi-select file picker).
   → **Kept as-is. Phase 3 / v1.3.0**, after v1.2.0 has made file selection a
   list rather than a single path.
4. **Live progress panel** (replacing the current blocking spinner):
   streams what the pipeline is doing right now ("Parsed Session 2 — 127
   records", "Filtering by cow list…", "Writing workbook…") and — merged
   with the old "preview before export" idea — also shows the record/cow
   counts that will actually be exported before final confirmation.
   → **Kept. Phase 3 / v1.3.0.** Its "preview before export" half is delivered
   by the single-parse plan object introduced in Phase 2 (**D1**): the confirm
   dialog describes counts that have already been computed, which is why they
   cost nothing. Progress reporting does **not** break the one-isolate
   synchronous pipeline invariant — see §31.4.
5. **Implausible cow-number warning**: flag (not block) any parsed cow
   number outside a sane range (e.g. absurdly large / clearly a typo) as a
   soft warning in the live panel and the summary, to catch data-entry
   mistakes early. Never silently drops or "corrects" the number.
   → **Kept, moved to cow-list import** (**D4**). Warning on conversion output
   fires on every conversion forever, after the bad number is already in the
   list; warning on import fires once, where the number enters the system and
   the user is already reviewing the list. "Never silently drops or corrects
   the number" is preserved unchanged. **Phase 1 / v1.1.0.**

### Group C — Records & safety (P2)
6. **Conversion History**: every completed conversion is logged (timestamp,
   number of source session files, session numbers/dates, record count,
   output filename) and the generated XLSX itself is retained so it can be
   re-downloaded or re-imported later without redoing the conversion.
   → **Kept and enlarged. Phase 4 / v1.4.0.** History becomes a real page
   inside the app (list + entry detail), not a background file. "Re-imported
   later without redoing the conversion" becomes an explicit **Import into
   DairySense** action on the entry detail, using the same import service and
   the same re-import guard as a fresh conversion. Two additions:
   - **6a. Import ledger** — each import attempt is recorded with its own
     state (`saved` → `launching` → `submitted` → terminal) so an import whose
     result could not be read is answerable afterwards instead of lost.
   - **6b. Workbook inspector** — **Open a workbook…** accepts *any* `.xlsx`,
     including workbooks produced before this feature existed or edited by
     hand, and shows exactly what is inside it: sheet name, headers as found,
     row count, each `(Date, Session)` pair with its cow numbers, totals, and
     anomalies. It can also cross-check the file against the active cow list
     and adopt an old workbook into History. This is what makes History useful
     on the day it ships, when it is otherwise empty.
7. **Delete from History**: the user can remove old entries (and their
   retained files) from inside the app.
   → **Kept, moved earlier to Phase 4 / v1.4.0** — it ships with the page that
   introduces the list, because a list that cannot be pruned grows unbounded.
   The retention *cap* stays Phase 6 / v1.6.0.
8. **Export History** to Excel or PDF, for sharing a record of past
   conversions outside the app.
   → **Kept, deferred to Phase 6 / v1.6.0.** Scope unchanged.
9. **Automatic cow-list backup**: every time the active cow list is
   replaced, the previous version is retained (not just overwritten), so a
   bad update can be rolled back.
   → **Kept, both halves, moved to Phase 1 / v1.1.0.** The automatic retention
   is delivered by the atomic cow-list write (**D7a/D-register**), which keeps
   the previous file as `cow_list.json.bak` as a side effect of never
   truncating in place. But that fallback is automatic and fires only on
   corruption, so "a bad update can be rolled back" also needs a **Restore
   previous list…** action (shows the backup's cow count and timestamp, asks,
   then swaps) — otherwise a *valid but wrong* list silently replaces a good
   one and nothing offers it back. See also §30.7.

### Group D — Distribution & protection (P2)
10. **Professional installer** (Windows `.exe`/`.msix`) replacing "just copy
    the build folder" — Start Menu entry, uninstaller, versioned.
    → **Kept, moved to first — Phase 1 / v1.1.0**, and narrowed to **Inno
    Setup `.exe`** (not MSIX: MSIX needs a signed package to install without
    developer mode, and its filesystem/registry virtualisation fights both the
    `%ProgramData%` data root and the fingerprint reads). Shipping to a machine
    the developer does not control is what makes durability release one.
11. **Hardware-locked licensing**: the app binds itself to the machine it is
    first installed on (machine fingerprint) and refuses to run if copied
    elsewhere; the developer issues a license/activation per machine.
    → **Kept, redesigned as a hard lockout — Phase 7 / v1.7.0.** Two states
    only, `licensed` and `blocked` (§30.14): no trial, no grace period, no
    read-only degraded mode. Activation is required before first use. The
    fingerprint is **strict — all four components must match** (§30.14). This
    is a deliberate, recorded decision: any false negative stops the farm
    until the developer is reached, accepted in exchange for the recovery
    guarantees in §30.15 and Phase 7's DoD.

### Group E — Look & feel polish (P3, last)
12. **UI redesign**: clean, professional, agriculture-appropriate visual
    identity — built *after* the functional features above, once the new
    screens (multi-file, live panel, history, dashboard) exist to design
    around.
    → **Kept, deferred to Phase 8 / v1.8.0**, and partly pre-empted: the
    `NavigationRail` shell (§31.3) is the structural half of the redesign and
    arrives early in Phase 4, because the History page needs somewhere to live.
    §28.12's own reasoning — design around finished screens — is why it is last.
13. **Dashboard home screen**: last conversion summary, active cow-list
    count, and a staleness warning if the cow list hasn't been updated in
    ~30 days.
    → **Split.** The dashboard screen itself is **Phase 8 / v1.8.0**. Its
    **~30-day staleness warning moves to Phase 1 / v1.1.0**, onto the existing
    cow-list card: the nullable-`lastUpdated` fix in Phase 1 exists *because*
    of this warning, so shipping the fix without a consumer would leave
    "unknown age ⇒ treat as stale" unobservable.
14. **Dark mode.**
    → **Kept, deferred to Phase 8 / v1.8.0.** (This is item 14; the heading
    above previously said 13 — see **D13**.)

### Added since the original list (not in the 14 above)

These come out of reviewing this plan against the shipped v1.0 code and the
decisions recorded in §29–§31. They are listed here so §36's traceability table
has a complete inventory, not because they change any of the 14 above.

- **Per-day / per-session missing-cow breakdown** — recovers the detail that
  batch-wide missing detection (§30.3) discards. **Phase 2.**
- **Restore previous cow list** — §28.9's unmet half (see item 9). **Phase 1.**
- **Workbook inspector** — item 6b above. **Phase 4.**
- **Fixed `%ProgramData%\AlfaMilk\` data root** + one-time copy-migration, the
  precondition that makes a licence lockout recoverable. **Phase 1.**
- **Support log** + copyable diagnostics — the only remote-diagnosis artefact
  once Constitution IV forbids showing raw errors. **Phase 1** (export zip in
  Phase 6).
- **Single-instance guard** and non-idle button disabling. **Phase 3.**
- **Atomic writes** for every JSON store and for the workbook itself
  (temp-then-rename). **Phase 1** / **Phase 2**.
- **Acceptance cases H–K** — the multi-date workbook question that gates
  Phase 2 (§33.5).

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

### 29.4 Automation approach — in-process, no helper executable

**Decided:** the automation runs **inside `alfa_milk.exe`** via `dart:ffi` and
`package:win32`. No bundled .NET helper process, no second executable in the
installer, no .NET SDK on the build host. (§29 originally offered a helper
process as one of three options; that option is withdrawn.)

Two tiers. **Which one applies is decided by the spike (Phase 5S), not
assumed** — the deciding question is whether the importer's window exposes
child `HWND`s at all.

- **Tier 1 — classic Win32 window messaging (preferred; no COM).** If the
  importer is Win32/WinForms, its button, dialogs and edit fields are real
  `HWND`s and the whole sequence is plain C calls that `package:win32` already
  binds: launch and keep the PID → enumerate top-level windows **filtered to
  that PID** → find the button by class + text → click it → find the next
  `#32770` → walk its children to the filename edit → set the text → confirm →
  read the result dialog's title and static text → dismiss. Only `int`s and
  UTF-16 pointers cross the FFI boundary: no COM, no vtables, no reference
  counting.
- **Tier 2 — `IUIAutomation` COM through FFI (contingency).** Required only if
  the spike finds no child `HWND`s (a WPF/UWP window). Higher cost: COM
  lifetime management, and whether ready-made Dart bindings for the UIA
  interfaces exist is **UNVERIFIED** — assume they may need hand-writing. This
  is the single biggest cost fork in the feature, which is why it is a spike
  output and not a design assumption.
- **Still rejected, unchanged from the original §29:** SendKeys and
  coordinate-clicking. Both break silently on DPI change, window movement and
  keyboard layout.

Three rules that are not optional, because each one is a silent-failure source:

- **Click with `PostMessage`, never `SendMessage`.** The click opens a *modal*
  dialog, and `SendMessage` blocks the caller until the target finishes handling
  the message — which would freeze Alfa Milk's UI thread behind a dialog the
  user cannot see. Setting the filename text is the one place a blocking send is
  correct (it must complete before the dialog is confirmed) and it targets a
  non-modal edit control.
- **Do not trust the classic dialog control identifiers** (`edt1`, `cmb13`).
  They exist only on the legacy `GetOpenFileName` dialog; the Vista+ common item
  dialog has a different tree. Locate the edit control by walking children by
  class, which works on both.
- **Never hardcode the §29 install path.** Discovery order: the path persisted
  from the last successful run → the §29 default → a bounded search of
  `%ProgramFiles(x86)%`/`%ProgramFiles%` under any folder matching
  `*airysense*` → ask the user to locate it once, then persist. `...\Debug\...`
  inside a shipped install path is a strong hint the vendor's layout is not
  stable across versions.
- **Bind to the launched PID.** Alfa Milk starts the process itself and
  enumerates only windows owned by that PID — never `FindWindow` by title, which
  would attach to a stale or second instance. If an instance is already running:
  exactly one → offer to attach; more than one → refuse with a clear message
  rather than guess.
- **Waits are deadline-based polls** (100 ms between attempts), never blocking
  sleeps and never spin loops, so the UI stays repaintable and Cancel stays
  live. Per-step budgets: window 10 s, Open dialog 5 s, **result dialog 30 s**
  (§29's suggested 15 s is likely too short for a real herd-database write;
  make it configurable, default 30 s).

### 29.5 Outcome taxonomy — four outcomes, none of them silent

The original §29 modelled success/failure. That is not enough: the dangerous
case is *"the file was handed over and we don't know what happened."*

| outcome | meaning | what the user is told and offered |
|---|---|---|
| `success` | result dialog title is `Tamam` | "DairySense loaded **N** records from *&lt;file&gt;*." → **Open DairySense** · **Done** |
| `failure` | result dialog title is anything else (e.g. `Hata`) | DairySense's own message verbatim, then: nothing was imported, enter the file manually instead → **Open the Excel file** · **Show file in folder** · **Try again** · **Close** |
| `unknown` | the file **was** submitted but no result dialog arrived before the timeout, or the process died mid-import | "The file was handed to DairySense but we could not read the result. It may or may not have been imported. Check DairySense before trying again — importing twice can duplicate a whole milking." → **Open DairySense to check** · **Open the Excel file** · **Show file in folder** · **Close**. **No one-click retry.** |
| `precondition_failed` | exe not found, window never appeared, button not found, access denied, workbook locked by Excel — **nothing was submitted** | the specific reason in one sentence, then: nothing was sent, enter the file manually → **Open the Excel file** · **Show file in folder** · **Try again** · **Close** |

**The manual fallback is a first-class path, not an error message.** On all
three non-success outcomes the dialog carries the generated workbook with it —
open it, or reveal it in Explorer — so the user's next step is one click and the
old manual routine is always reachable. See §30.13.

### 29.6 In-process crash safety

Stated plainly because it is the cost of dropping the helper process: **an
isolate does not contain a native crash.** A bad pointer in FFI takes down
`alfa_milk.exe` entirely. So the mitigations are structural, not defensive
wrappers: prefer Tier 1 (no COM ⇒ no refcount or vtable bug is possible); treat
"found nothing" as a normal `precondition_failed` outcome rather than
dereferencing; free every native allocation in a `finally`; never block the UI
thread; and — the actual recovery mechanism — **write the ledger's `submitted`
state before the call that could crash** (§30.11), so the next launch can report
`unknown` instead of losing the fact that an import may have landed.

The import sequence deliberately does **not** run inside `Isolate.run`: it is
wait-shaped rather than a pure computation, and it must stay observable and
cancellable. This is an explicit exception to the synchronous-pipeline
invariant, which governs the **conversion** pipeline only.

### 29.7 Elevation / UIPI — a silent failure the original section missed

If `MilkIntegration.exe` runs elevated and Alfa Milk does not, UIPI blocks all
input to its windows **silently**: child enumeration returns nothing or the
click returns 0, the window is visibly there, and the run looks like a hang.
Detect it explicitly (`GetLastError() == ERROR_ACCESS_DENIED (5)` after a failed
post) and report it as its own `precondition_failed` reason — "MilkIntegration
is running with higher privileges than Alfa Milk. Close it and let Alfa Milk
start it, or run Alfa Milk as administrator." Never retry into it.

### 29.8 Accepted risk, and the UNKNOWNs the spike must answer

**Risk (acknowledged, accepted by user, unchanged):** this is coupling to an
external app's UI. If `MilkIntegration.exe` is ever updated, automation may
break. Because the tool is small/internal and rarely changes, this risk was
accepted rather than falling back to "just open the app for the user."
Mitigation: fail loud and clear (never silently "look" successful), and keep a
manual fallback always available in the UI (§29.5).

Every Turkish and English UI string the automation matches on — `Load Milk
Data`, `Tamam`, `Hata`, the Open-dialog caption — is a **locale-dependent
input**, not a constant of nature. They live in one Dart constants file so a
vendor or locale change is a one-file edit.

**The following are unresolved, and each one changes the design or the cost.
They are answered by the Phase 5S spike (§32) on the real machine, before
Phase 5 is designed for real — not "during implementation":**

1. Does the importer's window expose child `HWND`s at all? → **decides Tier 1
   vs Tier 2, the single biggest cost fork in the feature.**
2. The actual class names and control tree of the button, the Open dialog and
   the result dialog (inspected with Accessibility Insights or equivalent) —
   this replaces the original "exact `AutomationId`s" item, which presumes
   Tier 2.
3. Can multiple `MilkIntegration.exe` instances coexist?
4. Behaviour when DairySense's own main application is open at the same time.
5. Is the exe elevated? (§29.7.)
6. Does the `...\Debug\...` segment of the install path survive a vendor
   update?

The spike's output is a written answer per question, appended to this section —
**not shipped code** (§32, Phase 5S). See **D12**.

## 30. New / Changed Business Rules for v1.1

These are additive to Part 1 §5 (Core Business Rules), not replacements. Rules
30.1–30.8 are the original eight, renumbered and annotated; **30.4 is reversed
and 30.6 is refined** (both marked below, both traced in §36). Rules
30.9–30.17 are new, and each one exists because a review found a way the app
could otherwise corrupt herd data silently — or, for 30.17, a way a late
licensing release could lock out a farm that was working the day before.

**30.1 Multi-file input is still filtered by the same single cow list.** The
cow list remains one active filter list, applied uniformly across every session
file in the batch — no per-file cow lists. *(Kept verbatim. This is
Constitution II at batch scale.)*

**30.2 Merged output is one workbook, one sheet, same 8 columns**, sorted in a
defined, deterministic order — never silently interleaved in an unpredictable
way. *(Kept; the ordering is no longer an open question.)* The order is
**report Date → Session → insertion index**, where insertion index is
source-file order and then original row order inside that file. The third key
is explicit because `List.sort` in Dart is **not stable**, so "original row
order within a session" cannot be left as an assumption. Date-then-session
rather than file-selection order, because the workbook is read by a human
before it is imported and a chronological workbook is auditable against the
paper reports; file-selection order is whatever the OS dialog happened to
return. See §33.1.

**30.3 Missing-cow detection spans all input files together**: a selected cow
is only "missing" if absent from *every* session in the batch, not just one.
The confirm dialog lists cows missing from the whole batch, once. *(Kept as the
blocking gate.)* Extended: the same dialog also shows a **non-blocking
per-day/per-session breakdown**, plus a "milked in some sessions only" line.
Rationale — batch-wide absence is a *data* question (a cow this batch cannot
account for at all) and is the only one where continuing risks silently
exporting nothing for a cow the user expected; per-session absence is a *herd*
question (a cow skipped a milking, was treated, dried off) and would fire on
almost every real batch, training the user to click through the dialog without
reading it. So it is shown, never blocking.

**30.4 Duplicate/overlapping sessions are a hard block.** *(**Reversed** — the
original rule warned and let the user proceed.)* If two input files resolve to
the same `(Date, Session)` pair, the batch stops and the message names **both
files**. No "export anyway" override. Unlike missing cows, there is no
legitimate reading of "the same session twice in one workbook": the result is a
whole milking counted twice in the herd database. If acceptance case **J**/**K**
(§33.5) shows DairySense rejects it anyway, our own block still stays — a clear
sentence from us beats `"Hata: Subquery returns more than 1 row"`. See **D6**.

**30.5 Auto-import never replaces the "ask every time" save step**; it is an
additional step *after* the XLSX is saved to disk normally (Part 1 FR-015 still
applies in full — the merged file is still saved to a user-chosen folder
first). Auto-import reads that same saved file. *(Kept verbatim.)*

**30.6 History never silently deletes.** Retained generated files persist until
the user acts; **nothing is auto-purged and there is no TTL.** *(Kept in
substance; refined.)* The retention cap added in Phase 6 (count + total bytes)
is not an exception to this rule, because it **always asks before deleting**
and shows what would be removed — a prompted cleanup, not a background purge.
A time-based TTL remains rejected: the age of a workbook says nothing about
whether the farm still needs it. See §33.4 and **D14**.

**30.7 Cow-list backup is automatic and silent** (no extra user action) but
restoring a previous version is an **explicit user action, never automatic**.
*(Kept — and now actually implemented.)* The automatic half is the atomic-write
`.bak` (§31.2); the explicit half is a **Restore previous list…** action that
shows the backup's cow count and timestamp and asks before swapping. The
automatic `.bak` fallback fires only on a *corrupt* read, so without the
explicit action a **valid but wrong** list silently overwrites a good one with
no way back — which is the case §28.9 was written for.

**30.8 License/hardware lock never destroys data.** A license failure blocks
the app from running conversions but must never delete the local cow list,
history, or `.xlsx` output already on disk. *(Kept verbatim, and it is what
makes 30.14 survivable: a blocked app puts the activation screen in **front
of** the data, it does not remove it.)*

**30.9 A batch is all-or-nothing, and a failure names the file.** *(New.)* If any
input file cannot be read or parsed, the whole batch stops, no workbook is
written, and the message says **which file** — "File 2 of 3 (`Session2 7-8.html`)
could not be read: …. No workbook was created. Fix or remove that file and
convert again." No partial export, ever: a workbook that silently contains two
of three sessions is indistinguishable from a correct one once it is on disk.
Guaranteed by construction — every file is validated and every row built before
the writer is called — not by cleanup code after a failure.

**30.10 An unparsable report date rejects the batch.** *(New.)* A report whose
Date cannot be parsed is a hard stop, naming the file. Two reasons: the Date is
the primary sort key (30.2), and the writer emits a text cell instead of a date
cell when parsing fails, so one merged workbook's Date column could otherwise
hold two different cell types. A missing session number is rejected the same
way — an empty session would collide in 30.4's duplicate check. See **D5**.

**30.11 A timeout is not a failure — `path_submitted` is the boundary.**
*(New; this is the most important safety rule in the automation.)* Once the
workbook path has been handed to DairySense, the external program may already
have written to the herd database. So: **before** submission a timeout is
`precondition_failed` and retrying is free; **after** submission it is
`unknown`, and the app must never offer a one-click retry, because a blind retry
risks importing a whole milking twice. The ledger's `submitted` state is written
to disk *before* the call that could crash, so an interrupted run is still
reported as `unknown` on the next launch rather than forgotten.

**30.12 An import is guarded by workbook content, not by filename.** *(New.)*
Before an import can start, the ledger is checked by the workbook's SHA-256:
already `success` → blocked, with what was imported and when, and an explicit
override; `unknown` → a hard warning and no one-click retry; `failure` →
allowed. The hash is the identity because the path is not stable — the user
chooses the save location every time, by design (30.5). See **D7**, and
acceptance case **J** (§33.5), which decides whether the `success` block is
absolute or advisory.

**30.13 A non-success import always offers the workbook for manual entry.**
*(New.)* On `failure`, `unknown` and `precondition_failed` the dialog carries the
generated workbook with it — **Open the Excel file** and **Show file in folder**
— so the pre-v1.1 manual routine is always one click away. The feature is
allowed to fail; it is not allowed to leave the user without a next step. See
§29.5.

**30.14 Licensing has exactly two states: `licensed` and `blocked`.** *(New,
and it replaces any reading of "licensing never blocks startup".)* A blocked app
opens to the activation screen and nothing else — no conversion, no import, no
cow-list edit, no history. There is no trial, no degraded mode, no read-only
mode, no grace period and no emergency unlock. The fingerprint is **strict: all
four components must match.** The user has accepted the resulting risk on the
record — a broken registry read, a replaced disk, a renamed machine or an OS
reinstall stops the farm until the developer is reached. This rule only works
because of 30.8 and 30.15: blocking puts a screen **in front of** the data, and
the data is somewhere a reinstall will find it. One exception to the
"phone the developer" path: an evaluation that *could not read* a component
(rather than read it and found it different) shows a **Check again** button that
re-runs the check in place. Unreadable and changed are never collapsed into one
reason.

**30.15 All persistent data lives in one fixed, install-independent location,
and there is no silent fallback.** *(New; the condition the user attached to
30.14.)* `%ProgramData%\AlfaMilk\` holds the cow list, its backup, history,
the ledger, settings, the license and the log. Nothing the app must keep lives
beside the exe, so uninstall + reinstall + reactivate recovers a farm exactly as
it was. Migration from the old location is a **copy, never a move**, run once
behind a marker file, so a rollback to v1.0 still finds its data. If the folder
cannot be created or written, the app shows a blocking, actionable error naming
the path and the reason — it must **never** quietly write somewhere else, which
is precisely how "my cow list vanished after the reinstall" happens. Accepted
trade-off: the folder is machine-wide, so a second Windows account shares one
cow list and one history; for a single-operator farm that is the intent.

**30.16 Retention never deletes without asking.** *(New; the boundary that keeps
30.6 true.)* Any cleanup — the retention cap, the orphan sweep — shows what would
be removed and how much space it frees, and waits for confirmation. There is no
code path that deletes a retained workbook or a history entry without the user
saying yes.

**30.17 The activation fingerprint is readable before it is ever enforced.**
*(New; the rule that keeps the late licensing release from locking out a working
farm.)* Because licensing ships last among the functional releases (Phase 7),
the farm runs an unlicensed but fully working install for the whole v1.2.0–v1.6.0
stretch — and the update that adds enforcement would otherwise turn that working
install into a lockout screen whose request code can only be read *off the very
machine it just blocked*. So Phase 6 exposes a **read-only request-code readout**:
it computes the activation request code from the same four fingerprint components
Phase 7 verifies, shows it with a **Copy** button, and **enforces and blocks
nothing**. The developer collects the code and issues `license.dat` *before*
Phase 7 is handed over, so the update opens `licensed` and the activation screen
never appears on a machine that was working the day before. The two readers are
the same code by construction — a test asserts the panel and the activation
screen produce a byte-identical code for one machine — so the pre-issued license
cannot be subtly wrong. This readout only reads; it is not an enforcement point
and it is not the exception in 30.14.

## 31. Architecture Additions

Extends the existing feature-first Clean Architecture (Part 1 §12); no
existing feature module is restructured.

### 31.1 Module map (corrected)

Two corrections against the original tree are marked **[CORRECTED]** and traced in §36.3 — both were
designs that cannot work, not preferences.

```text
lib/
├── features/
│   ├── home/                       # existing (v1.0) — Alpro→DairySense pipeline
│   │   ├── data/data_sources/      # alpro_parser.dart — UNCHANGED, still single-file,
│   │   │                           #   called once per report  [CORRECTED]
│   │   │                           # dairy_sense_writer.dart — UNCHANGED (+ temp-then-
│   │   │                           #   rename write, D11); constants stay the single
│   │   │                           #   source of truth for the reader in history/
│   │   ├── domain/entities/        # + SessionReportSummary, BatchConversionResult,
│   │   │                           #   ConversionPlan (single-parse, D1), BatchProgress
│   │   ├── domain/use_cases/       # + SortDairySenseRowsUseCase  [CORRECTED — replaces
│   │   │                           #   the planned MergeReportsUseCase]
│   │   ├── data/repos/             # + runBatchConversion() + _batchPipeline (sync, one
│   │   │                           #   Isolate.run, SendPort progress)
│   │   └── presentation/           # + multi-file selection, live progress panel,
│   │                               #   drag&drop dropzone, per-day/session breakdown
│   ├── cow_list/                   # existing — + atomic write & .bak, Restore previous
│   │                               #   list…, implausible-number check on import
│   ├── dairysense_import/          # NEW feature module
│   │   ├── data/                   #   windows_ui_automation_client.dart — in-process
│   │   │                           #   dart:ffi + package:win32 only, no process bridge
│   │   │                           #   milk_integration_strings.dart (locale-dependent)
│   │   │                           #   import_ledger_store.dart (one JSON file / attempt)
│   │   ├── domain/                 #   ImportOutcome, ImportEvent, ImportLedgerEntry,
│   │   │                           #   RunDairySenseImportUseCase
│   │   └── presentation/           #   "Import into DairySense" + 4 outcome dialogs,
│   │                               #   each carrying the manual-fallback actions
│   ├── history/                    # NEW feature module
│   │   ├── data/                   #   history_store.dart — one JSON file per entry,
│   │   │                           #   NO index  [see D10] + retained-files dir
│   │   │                           #   dairy_sense_reader.dart (workbook inspector)
│   │   ├── domain/                 #   ConversionHistoryEntry, WorkbookInspection,
│   │   │                           #   use_cases (list/delete/export/inspect/adopt)
│   │   └── presentation/           #   entry list, entry detail, inspector view
│   ├── licensing/                  # NEW feature module
│   │   ├── data/                   #   machine_fingerprint.dart, license_store.dart
│   │   ├── domain/                 #   LicenseState (licensed | blocked), BlockReason,
│   │   │                           #   EvaluateLicenseUseCase
│   │   └── presentation/           #   activation/blocked screen — the whole app when
│   │                               #   blocked; Check again only on evaluationError
│   ├── shell/                      # NEW — NavigationRail shell, the new composition
│   │                               #   root: Convert · History · (Dashboard slot).
│   │                               #   The single place licensing gates the app.
│   └── dashboard/                  # NEW feature module (last release)
│       └── presentation/           #   dashboard_screen.dart
├── core/
│   ├── helper_functions/           # + app_data_dir.dart (%ProgramData%\AlfaMilk\),
│   │                               #   write_json_atomic.dart, support_log.dart
│   ├── errors/                     # + BatchParseFailure, UnexpectedFailure (D2),
│   │                               #   ImportFailure, ImportUnknownOutcomeFailure,
│   │                               #   LicenseFailure, SourceChangedFailure
│   └── theme/                      # NEW — design tokens for the UI redesign + dark mode
└── tool/license_cli/               # NEW — offline license issuance (developer-only,
                                    #   shares the payload/signature code with the app)
```

### 31.2 Merge — per-report conversion, concatenate rows

**Multi-file merge** lives inside the existing `home` feature (it's a variant of
the same pipeline, not a new domain), reusing `FilterRecordsUseCase` /
`DetectMissingCowsUseCase` / `BuildDairySenseRowsUseCase` **unchanged**.

**[CORRECTED]** The original wording — *"parse N files, concatenate
`AlproRecord`s with their source Date/Session before filtering"* — cannot work:
`AlproRecord` carries no date and no session, so that concatenation destroys the
provenance it claims to preserve, and it would force entity changes on all three
reused use cases. The correct shape is the inverse: **run the existing
per-report pipeline once per file and concatenate its `DairySenseRow`s.**
`DairySenseRow` already carries `date` and `session`, and
`BuildDairySenseRowsUseCase` already stamps them from `report.date` /
`report.session` — so per-row provenance becomes structurally guaranteed rather
than maintained by hand, and **no entity changes are needed at all.** This is
precisely what makes the plan's own claim ("the three v1.0 use cases are reused
unchanged") true.

So the batch is: for each file → parse → validate (date parseable, session
present, `(date, session)` not already seen) → filter → detect missing → build
rows → append; then sort all rows once (§30.2), then write once. The parser is
**not** extended to accept a list of paths; it stays single-file and is called N
times. `SortDairySenseRowsUseCase` replaces the planned `MergeReportsUseCase` —
what is merged is rows, not reports.

The batch pipeline stays **synchronous inside one `Isolate.run`**, per the v1.0
invariant. Progress does not break that invariant: a `SendPort` is sendable and
`SendPort.send` is synchronous and non-blocking, so it can be captured by the
isolate closure and called from deep inside sync code. The authoritative result
is still the value `Isolate.run` returns — never assembled from progress
messages — so there is one result path and no way for the UI to show success
while the pipeline threw. Progress payloads are primitive maps, emitted per
file and per phase, never per row.

The batch-wide missing set is `selected − ⋃(cow numbers seen in any report)`: a
cow with data in any session is not batch-missing (§30.3).

### 31.3 Persistence, and what everything now writes through

`core/helper_functions/app_data_dir.dart` resolves the one data root
(§30.15) and replaces **every** `getApplicationSupportDirectory()` call —
today `cow_list_store.dart` is the only such consumer, which is exactly why
this lands in the first phase, *before* any new store is written against the
old location.

`write_json_atomic.dart` is the one write path for every JSON file the app
owns (cow list, history entries, ledger entries, settings): temp file with
`flush: true` → move the existing target aside as `.bak` → rename temp onto the
target. Every interruption point leaves either the old file or the new one, and
the `.bak` it produces **is** feature §28.9's automatic backup — the same few
lines deliver both. Workbooks get the same treatment with a `.partial` temp
name (**D11**), so a crash mid-write can never leave a corrupt file at the path
the user believes holds their data.

History is **one JSON file per entry with no central index** (**D10**): listing
is a directory enumeration, an unreadable file is skipped with a soft warning,
and delete removes the workbook before the entry. This eliminates the whole
class of "the index says 40 entries, the disk has 38" bugs that a single
rewritten `history.json` would introduce.

### 31.4 Isolation of the two risky subsystems

- **DairySense import automation** is isolated in its own feature/module
  specifically because it's an OS-level integration with a different failure
  mode (external process, timeouts, window-not-found) than the rest of the
  app, which is pure file IO. Keeping it isolated means a break here can
  never take down the core conversion pipeline. *(Kept — with the honest
  caveat from §29.6: module isolation is not process isolation, so a native
  FFI fault still ends the process. The isolation buys reviewability and a
  single blast radius for logic errors, not crash containment.)*
- **The workbook inspector is the writer's mirror, and shares its constants.**
  `DairySenseReader` imports `dairySenseSheetName` and the 8 header strings from
  `dairy_sense_writer.dart` — never copies them, because a copy is how the two
  halves drift. It reuses `normalizeHeader` / `normalizeCowNumber` /
  `parseReportDate`, reads column order from the header row rather than assuming
  it, and reverses both deliberate transforms: `seconds = hour × 60 + minute`
  (the exact inverse of the Milking Time remap) and Date read from either a date
  cell or a text cell (**D5**). Like the writer, it is synchronous and
  Flutter-free.
- **Licensing** is checked at app startup, before any destination is reachable,
  as its own gate screen — and it is checked in **exactly one place**, the rail
  shell, which renders the activation screen instead of its destinations when
  the state is `blocked`. No per-button `if (licensed)` test anywhere: a feature
  that forgets one is how a "hard lockout" ends up half-enforced. Re-evaluation
  happens at launch and after a license file is loaded, **never on a timer** —
  no background re-check may turn a working morning into a blocked one
  mid-conversion.

### 31.5 Unchanged from v1.0 (stated so it stays true)

`AlproRecord`, `AlproReport`, `CowList`'s cow numbers, `DairySenseRow`,
`AlproParser`, `FilterRecordsUseCase`, `DetectMissingCowsUseCase`,
`BuildDairySenseRowsUseCase`, `DairySenseWriter`'s output format and all eight
header constants, and the single-file conversion path. The only v1.0 entity
change in all of Part 2 is `CowList.lastUpdated` becoming nullable (**D3a**/7b,
Phase 1), which is compile-time checked, so nothing can silently keep the old
assumption.

## 32. Phases for v1.1+ — eight releases and one spike

Replaces the original Phases A–F (five feature groups in one release). Each
phase below is **independently shippable** and carries its own Goal, Scope,
Depends on, Defects addressed and Definition of Done — the same heading idiom as
Part 1 §23, with the per-phase DoD that Part 1 kept in §20/§26 pulled into each
entry, because there are now eight releases instead of one.

The user's stated priority was **"time-savers first"** — merge and auto-import
before polish. That now holds strongly: merge is Phase 2, the first release after
the durability floor, and every functional feature (merge, live progress, history,
one-click import) ships **before** licensing. Licensing was deliberately moved to
Phase 7, second-to-last — after all the time-savers and immediately before the
cosmetic UI redesign — so the farm gets the features that save it work as early as
possible and the hardware lock arrives once the app it protects is feature-complete.
Each functional phase still sits where a hard prerequisite puts it (merge needs
acceptance cases H–K; import needs the ledger that makes its `unknown` outcome
recoverable). Phase 1 comes first not as polish but as the floor: shipping to a
machine the developer does not control requires durable data and an installer to
exist **before** anything depends on them.

**Accepted consequence of moving licensing to Phase 7 (on the record).** v1.2.0
through v1.6.0 ship and run on the farm's machine with **no hardware lock and no
activation enforcement**. That is a deliberate decision, not an oversight: the
functional releases are usable and shippable without licensing, and the enforcement
gap is accepted in exchange for delivering the time-savers first. Its one real
hazard — a working, unlicensed install being turned into a lockout screen by the
v1.7.0 update — is defused by §30.17: v1.6.0 exposes the machine's request code so
`license.dat` can be issued *before* v1.7.0 ships.

Ordering rules that produced this sequence:

- **Durability before anything that writes.** The `%ProgramData%` root must land
  before any new store is written against the old location, or every later store
  needs its own migration.
- **The data root before any new store, and before the lockout.** Its immediate
  job is that the history and ledger store (Phase 4) must be born in the fixed
  location — a root that arrived later would strand that data and force a second
  migration. It also makes the eventual hard lockout survivable, because reinstall
  + reactivate then restores a farm exactly as it was (§30.15); with licensing now
  at Phase 7 that benefit is distant, but the store reason makes the root a Phase 1
  requirement on its own.
- **The ledger and the History page before auto-import.** Without them, an
  `unknown` import outcome is unrecoverable and its advice ("check DairySense")
  has nothing to check against.
- **Unknown facts get a gate, not an estimate.** Phase 2 waits on H–K; Phase 5
  waits on the Phase 5S spike.
- **The request code before the lockout.** Phase 6 reads the machine's request
  code with no enforcement so `license.dat` is issued before Phase 7 turns the
  same fingerprint into a gate (§30.17).

### Phase 1 — v1.1.0 "Distribution & cow-list durability"

**Goal.** The farm can install Alfa Milk from a single installer, and its cow
list survives a crash, a bad update and a reinstall.

**Scope.**
- Inno Setup installer (§28.10): per-machine install of the whole Flutter
  bundle to `%ProgramFiles%\Alfa Milk\`, app-local MSVC runtime DLLs, Start
  Menu shortcut, fixed `AppId`, upgrade and uninstall that **never** touch
  `%ProgramData%\AlfaMilk\`, documented SmartScreen click-through (unsigned).
- `core/helper_functions/app_data_dir.dart` — the one data root (§30.15) — and
  the one-time **copy** migration from app-support behind a marker file, with
  the blocking actionable error and **no silent fallback**.
- `core/helper_functions/write_json_atomic.dart` + `cow_list_store.dart`
  switched onto it: temp → `.bak` → rename, `.bak` fallback on corrupt read
  (§28.9's automatic half, §31.3).
- **Restore previous list…** on `CowListCard` — the explicit half of §30.7,
  showing the backup's cow count and timestamp before swapping.
- `CowList.lastUpdated` becomes nullable; `last updated: unknown` in the UI;
  unknown age counts as stale; the ~30-day staleness warning from §28.13.
- Implausible-cow-number check moved to **cow-list import** (§28.5, D4).
- `core/helper_functions/support_log.dart` — rolling capped log in
  `<dataRoot>\log\` (§28's new support-log item).
- `UnexpectedFailure` in `failures.dart`, and the raw exception text routed to
  the log instead of into a `Failure` message.

**Depends on.** Nothing. This is the floor for every later phase.

**Defects addressed.** D2, D4, D9 (log), plus 7a/7b from the review.

**Definition of Done.**
- Installer runs on a clean Windows VM with no Visual Studio present, and the
  app launches.
- Upgrading over an existing install keeps the cow list; uninstalling keeps
  `%ProgramData%\AlfaMilk\` with no prompt and no checkbox offering to remove
  it.
- A standard (non-admin) Windows account can save a cow list, i.e. the
  ProgramData ACL is right.
- Named tests green: corrupt `cow_list.json` + valid `.bak` → the backup loads;
  a failed save leaves the previous list intact; a stray `.tmp` is ignored;
  unparsable timestamp → `lastUpdated == null` **and** the list's cow numbers
  are kept; `null` renders as unknown and counts as stale.
- Migration tests green: old file present + empty data root → copied, marker
  written, **old file still on disk**; marker present → does not re-run;
  unwritable root → the blocking error, never a silent write elsewhere.
- No `Failure` in the codebase interpolates an exception into its message.
- `flutter analyze` clean, `flutter test` green.

### Phase 2 — v1.2.0 "Multi-session merge"

**Goal.** The user selects any number of Alpro HTML session files and gets one
merged DairySense workbook, in a deterministic order, with every v1.0 business
rule still holding.

**Scope.**
- `pickHtmlFile()` gains `allowMultiple: true`; `MainScreen`'s single picked
  path becomes a list.
- `runBatchConversion()` + `_batchPipeline` (§31.2): per file — parse →
  validate → filter → detect missing → build rows → append; then sort once,
  write once. Still synchronous, still one `Isolate.run`.
- `SortDairySenseRowsUseCase`: date → session → insertion index (§30.2).
- `SessionReportSummary`, `BatchConversionResult`, and the single-parse
  `ConversionPlan` that removes the double-parse window (D1).
- Batch-wide missing gate kept (§30.3) **plus** the non-blocking per-day /
  per-session breakdown, in the requested format, and the "milked in some
  sessions only" line.
- Duplicate `(Date, Session)` hard block naming both files (§30.4, D6);
  unparsable date or missing session rejects the batch (§30.10, D5).
- `BatchFileError` → `BatchParseFailure`: fail the whole batch, name the file,
  write nothing (§30.9).
- Workbook written to `<target>.partial` then renamed (D11).

**Depends on.** Phase 1. **Gated on acceptance cases H–K passing (§33.5)** —
until DairySense is confirmed to accept a multi-date workbook and to attribute
rows to the right date and session, this release does not start. If H or I
fails, the design changes to one workbook per date and this entry is rewritten
before any code is written.

**Defects addressed.** D1, D5, D6, D11.

**Definition of Done.**
- Three real session files spanning two dates → one workbook, rows in date →
  session → original order, imported successfully into real DairySense.
- Every v1.0 rule still holds on the batch path: filter-not-mapping, no
  invented rows, `Conductivity`/`temperature` = 0, Date/Session from the
  reports, output folder chosen every time.
- Named tests green: row count == sum of per-file matches; each row carries its
  own file's date and session; sort is deterministic with a non-numeric session
  and with duplicate `(date, session, cow)`; a mid-batch failure leaves **no
  file at the output path**; a merged workbook's Date column is uniformly
  `DateCellValue`; duplicate `(date, session)` is blocked and both filenames
  appear in the message; the breakdown renders `all cows present` and a
  single-session day correctly.
- The source files are re-verified by hash before writing; a file changed
  during the dialogs fails with `SourceChangedFailure` naming it.
- The three real reports are added to `test/fixtures/` as a two-date regression
  input.
- `flutter analyze` clean, `flutter test` green.

### Phase 3 — v1.3.0 "Live progress & drag and drop"

**Goal.** A multi-file conversion shows what it is doing while it runs, and files
can be dropped onto the window instead of picked.

**Scope.**
- `SendPort`-based progress out of the batch isolate (§31.2): per-file and
  per-phase events, primitive payloads, ordered.
- `ConversionInProgress(lines, filesDone, filesTotal, phase)` replacing the
  single `ConversionLoading`; the write step is labelled indeterminate rather
  than given a fake percentage.
- `desktop_drop` dropzone, multi-file, `.html`/`.htm` filtered, with the same
  validation path as the picker.
- Buttons disabled on **any** non-idle state, not just `ConversionLoading`
  (D8), and a single-instance guard at startup that focuses the existing
  window instead of starting a second app.
- Honest cancellation semantics for conversion: `reset()` valid only from
  idle/success/failure (D3). Real mid-run cancellation stays deferred — it
  needs `Isolate.spawn` + `kill()`, and it is only safe because Phase 2
  already writes through `.partial`.

**Depends on.** Phase 2 (there is nothing to report progress on before the
batch path exists).

**Defects addressed.** D3 (conversion half), D8, D15 (`desktop_drop`).

**Definition of Done.**
- A 3-file batch shows per-file lines and a `filesDone/filesTotal` bar, and the
  window stays repaintable throughout.
- The authoritative result still comes from the isolate's return value — a test
  asserts a failing pipeline reports failure even after progress events were
  emitted.
- Dropping 3 files produces the same result as picking the same 3 files.
- Dropping a non-HTML file is rejected with the same message as the picker.
- Double-clicking CONVERT cannot start two conversions; launching the app twice
  focuses the first window.
- `flutter analyze` clean, `flutter test` green.

### Phase 4 — v1.4.0 "History, ledger and the workbook inspector"

**Goal.** Every conversion is recorded, visible in the app as a real page, and
any DairySense workbook — including ones made before this feature existed — can
be opened and read back.

**Scope.**
- `NavigationRail` shell as the new composition root: **Convert** · **History**
  (a Dashboard slot for Phase 8). Picked paths and the active cow list move
  above the rail so switching destinations never loses a selection.
- `ConversionHistoryEntry` + `ImportLedgerEntry`; one JSON file per entry, no
  index (§31.3, D10); retained workbook copies; workbook-then-entry delete
  order; a startup orphan sweep that only ever *offers* to reclaim space.
- History entry list (newest first, import badge, retained-file state) and
  entry detail (per-day/session breakdown reusing Phase 2's renderer,
  batch-missing, warnings, source names + hashes, chosen output path, every
  import attempt with its verbatim result text).
- Entry actions: **Open the Excel file**, **Show in folder**, **Save a copy
  as…**, **Delete** (§28.7, moved earlier), and **Import into DairySense** —
  §28.6's "re-import later without redoing the conversion" — which is present
  but inert until Phase 5.
- **Open a workbook…** → `DairySenseReader` inspector (§31.4): what is in the
  file, distinct `(Date, Session)` pairs with row counts, cow numbers per
  session, totals, anomalies; cross-check against the active cow list reusing
  `DetectMissingCowsUseCase` unchanged; **adopt into history** for pre-ledger
  workbooks.
- Ledger state transitions written atomically **before** the corresponding
  action, so an interrupted import is recoverable as `unknown`.

**Depends on.** Phase 1 (data root + atomic writes), Phase 2 (the batch result
is what an entry records).

**Defects addressed.** D10, D15 (`crypto`).

**Definition of Done.**
- A conversion produces a history entry; the app is killed mid-write and the
  entry list still loads, skipping the unreadable file with a soft warning.
- Deleting an entry removes the retained workbook first; an interrupted delete
  shows "file no longer available", never a crash.
- **Round-trip test green:** `DairySenseWriter.write(rows)` → `DairySenseReader`
  → every cow number, date, session and **milking time in seconds** comes back
  identical. This is what pins `seconds = hour × 60 + minute` as the true
  inverse of the writer's remap.
- Inspector tests green: a `TextCellValue` date and a `DateCellValue` date
  normalise identically; a non-DairySense workbook yields the friendly
  "doesn't look like a DairySense import workbook" failure, not a crash; the
  headers-only `dairy_sense_template.xlsx` fixture reports 0 rows.
- The reader imports the writer's sheet-name and header constants — a test
  fails if either side is duplicated or drifts.
- Switching rail destinations mid-selection keeps the picked files.
- `flutter analyze` clean, `flutter test` green.

### Phase 5S — `MilkIntegration.exe` spike (**not a release — produces no shippable code**)

**Goal.** Replace §29's UNKNOWNs with written, dated answers, on the real
machine, against the real importer — before Phase 5 is designed for real.

**Scope.** Observation only. Run `MilkIntegration.exe`, inspect it with
Accessibility Insights (or equivalent) plus a throwaway probe, and answer the six
questions in §29.8. No feature code, no module, no tests, no version bump.

**Depends on.** Access to the machine with DairySense installed.

**Defects addressed.** D12.

**Definition of Done.**
- Each of §29.8's six questions has a written answer appended to §29, with the
  date it was observed.
- **The tier is decided and recorded:** Tier 1 (`user32` messaging) or Tier 2
  (`IUIAutomation`), with the evidence.
- The exact class names / control tree needed to locate the button, the Open
  dialog's filename field, and the result dialog are recorded verbatim.
- Elevation status recorded.
- Phase 5's Scope below is rewritten against those findings **before** it starts.
- **No files under `lib/`, `test/` or `tool/` are added or changed by this
  phase.** Any probe code is thrown away; if it looks shippable, it was out of
  scope.

### Phase 5 — v1.5.0 "One-click DairySense import"

**Goal.** After saving a workbook, one button loads it into DairySense — and
whatever happens, the user is told exactly what happened and always has the
manual route one click away.

**Scope.**
- `dairysense_import` feature module: in-process FFI client on the tier the spike
  chose, driven as an async state machine over `ImportEvent` (§29.4).
- Exe discovery chain with the located path persisted; PID binding; elevation /
  UIPI detection; deadline-based polls; `PostMessage`-not-`SendMessage`.
- The four outcomes with their dialogs and their manual-fallback actions
  (§29.5, §30.13), all text `SelectableText`.
- Ledger transitions written **before** each risky step (§30.11); re-import guard
  by workbook SHA-256 (§30.12, D7); preconditions before the button enables
  (workbook exists, not locked by Excel, exe found).
- Honest cancellation: before `path_submitted` → kill our process,
  `precondition_failed`; after → the button becomes **Stop waiting** and the
  outcome is `unknown`, never `cancelled` (D3).
- Advisory lock so two imports cannot run at once (D8).
- Every Win32 step logged with the `HWND` and `GetLastError()` to the support
  log, never to the screen (D9).

**Depends on.** Phase 4 (ledger + History page — an `unknown` outcome is only
recoverable if it is recorded and visible), Phase 5S (the tier decision), and
acceptance case **J** (§33.5), which decides whether the re-import block is
absolute or advisory.

**Defects addressed.** D3 (import half), D7, D8 (import half), D12 (consumes the
spike's answers).

**Definition of Done.**
- On the real machine: a successful import reports the record count DairySense
  itself reported, and the ledger shows `success`.
- A deliberately bad workbook produces `failure` with DairySense's own message
  shown verbatim, and the **Open the Excel file** button opens it.
- With `MilkIntegration.exe` absent/renamed → `precondition_failed`, nothing
  submitted, manual fallback offered, **Try again** available.
- Killing the importer after submission produces `unknown` with **no one-click
  retry**, and re-launching Alfa Milk still reports that attempt as `unknown`.
- Running the importer elevated produces the elevation message, not a hang.
- Importing the same workbook twice is blocked by hash with what was imported and
  when.
- The workbook open in Excel is refused **before** launching anything.
- Result-text parsing is unit-tested off-machine (`"<N> kayıt başarıyla
  yüklendi."` → N; unexpected titles → `failure`).
- First real runs are done **with a DairySense backup taken first**, against a
  workbook whose contents are already known-imported, so a duplicate is
  observable rather than destructive.
- `flutter analyze` clean, `flutter test` green.

### Phase 6 — v1.6.0 "History polish"

**Goal.** History stays useful and bounded after months of daily use, a failure
on the farm can be diagnosed remotely, and the developer can read the machine's
request code **before** the licensing release ships.

**Scope.**
- Retention cap: keep the last N (default 60) **and** a total-bytes cap (default
  200 MB), oldest first — **always asking, always showing what would be removed
  and how much space it frees** (§30.6, §30.16, D14). Current usage shown in the
  History view.
- **Export history to Excel or PDF** (§28.8), unchanged in scope.
- Orphan sweep surfaced as a prompted action.
- **Export diagnostics** — a zip of the capped log plus the selected history
  entry (D9's second half).
- **Request-code readout** — a read-only diagnostics panel showing this machine's
  activation **request code**, computed from the same four fingerprint components
  Phase 7 will verify, with a **Copy** button. It enforces nothing and blocks
  nothing; it exists so the developer can collect the fingerprint and issue
  `license.dat` **before** Phase 7 ships (§30.17). Component *names* only in the
  copyable text, never values.

**Depends on.** Phase 4.

**Defects addressed.** D14, D9 (zip half), D15 (a PDF package).

**Definition of Done.**
- Exceeding either cap prompts, names the entries, states the space, and deletes
  nothing until confirmed; declining leaves everything in place.
- No code path deletes a retained workbook or entry without confirmation — a
  test asserts it.
- Export produces a file that opens in Excel / a PDF viewer and matches the
  entry list.
- The diagnostics zip contains the log and the entry, and **no fingerprint
  values and no license payload**.
- The request-code panel shows a code on the farm's machine, and the code it
  shows is **byte-identical** to the one Phase 7's activation screen will show
  for the same machine — a test asserts both call the same fingerprint code.
- The request-code panel **gates nothing**: removing `license.dat`, or having
  none at all, changes no behaviour anywhere in v1.6.0.
- `flutter analyze` clean, `flutter test` green.

### Phase 7 — v1.7.0 "Licensing"

**Goal.** Alfa Milk runs only on machines the developer has activated, and a
blocked machine can be recovered without losing a single row of farm data.

**Scope.**
- `licensing` feature module: signed `license.dat` in `<dataRoot>`, Ed25519
  verification with only the public key embedded in the app.
- **Strict all-four** hardware fingerprint: Windows `MachineGuid`, motherboard
  serial, system volume serial, machine name. All read in a background isolate
  at launch, never on the UI thread.
- Two states only, `licensed` / `blocked` (§30.14). One enforcement point, the
  rail shell (§31.4).
- Activation screen: plain-language reason, large copyable **request code**,
  **Load license file…** (no restart), **Copy diagnostics** (component *names*
  only, never values), the developer's contact line, and the explicit
  reassurance that the cow list and history are safe in
  `C:\ProgramData\AlfaMilk`.
- **Check again** — on `BlockReason.evaluationError` only. A component that
  could not be *read* is never reported as a component that *changed*.
- Clock-rollback block via a monotonic `lastSeenUtc` high-water mark; clears
  itself once the clock is sane.
- `tool/license_cli/` — offline issuance, sharing the payload/signature code
  with the app so signer and verifier cannot disagree.
- **Pre-issued activation for the farm's existing install** (§30.17): the
  request code read by Phase 6's panel is used to issue `license.dat` *before*
  this release is handed over, so the update never presents a lockout screen to
  a machine that was working the day before.

**Depends on.** Phase 1 (the installer places the license file location and its
ACL; the data root is what makes a lockout recoverable) and Phase 6 (its
request-code panel is how the fingerprint is collected before this ships).

**Defects addressed.** D9 (diagnostics on a blocked app), D15 (`cryptography`).

**Definition of Done.**
- Activate → `licensed`. **Move the whole app folder to another drive → no
  change in state** (nothing in the fingerprint is path-derived).
- Rename the machine → `blocked` / `fingerprintMismatch`; a reissued license
  round-trips the request code back to `licensed`.
- Corrupt `license.dat` → actionable screen with a copyable request code and the
  "your data is safe" line. **Load license file…** recovers with **no restart**.
- Block the registry/PowerShell read → `blocked` / `evaluationError` **with
  Check again**, and one click returns to `licensed` with no license file
  involved. **Check again is absent** on `fingerprintMismatch` and
  `noLicenseFile`.
- Clock set back a week → `clockRollback`; fixing the clock clears it.
- **Uninstall, reinstall, reactivate → cow list, history and ledger all back,
  nothing lost.** This is the test that makes the accepted risk survivable; it
  is never skipped. Because licensing now ships eighth, this test runs against a
  data root already holding months of real history, ledger entries and logs —
  which is the state that actually matters and could not be tested when this
  release sat second.
- **Upgrade rehearsal:** on a machine running v1.6.0 unlicensed with real data,
  install v1.7.0 **with `license.dat` already issued and placed** → the app
  opens `licensed` and the farmer never sees the activation screen. Then repeat
  **without** the file → the activation screen appears in front of intact data,
  and the request code it shows matches the one v1.6.0's panel reported. Both
  halves are required: the first is the intended path, the second proves the
  fallback is survivable rather than assumed.
- App left open for an hour is **never** re-checked on a timer.
- No `if (licensed)` test exists outside the shell.
- `flutter analyze` clean, `flutter test` green.

### Phase 8 — v1.8.0 "UI redesign, dashboard and dark mode"

**Goal.** The app looks like a product the farm paid for, and opens on a screen
that answers "where do we stand" at a glance.

**Scope.**
- `core/theme/` design tokens; a clean, professional, agriculture-appropriate
  look applied across the rail's destinations (§28.12).
- **Dashboard** as a rail destination (§28.13): last conversion summary, cow-list
  count and age, last import outcome, quick actions. The staleness warning
  shipped in Phase 1 is surfaced here as well, not moved.
- **Dark mode** (§28.14).
- Cow list promoted to its own destination if the redesign calls for it.

**Depends on.** Phase 4 (the `NavigationRail` shell already exists, which is what
makes the dashboard a small addition rather than a restructure).

**Defects addressed.** none — this phase is deliberately cosmetic and ships last,
per the user's "polish/UI last" priority.

**Definition of Done.**
- Light and dark both legible at 100 % and 150 % Windows scaling, with no
  clipped text.
- Every dialog remains `SelectableText` (acceptance case G) after retheming.
- The dashboard shows real values from history and the cow list, never
  placeholders.
- No regression in the A–G acceptance cases.
- `flutter analyze` clean, `flutter test` green.

## 33. Open Questions for v1.1 — answered, with the two that stay open

The five questions originally listed here are all resolved below, each with its
reason and the rule or phase that now enforces the answer. Two residual unknowns
remain, and neither is left to implementation time: **§33.3** is owned by Phase 5S
(the spike) and **§33.5** is a blocking manual test that gates Phase 2. A sixth
subsection was added because the original Q5's premise changed.

### 33.1 Merged-row ordering — **ANSWERED: date, then session, then insertion order**

Sort by `parseReportDate(row.date)` ascending, then by session ascending
(numeric first, non-numeric after), then by insertion index — which is
source-file order, then original row order inside that file.

*Reason.* The workbook is read by a human before it is imported, and a
chronological workbook is auditable line-by-line against the paper reports.
File-selection order is whatever the OS file dialog happened to return, which is
not a meaningful order. The third key is not optional: Dart's `List.sort` is
**not stable**, so "original order within a session" has to be an explicit
tie-breaker rather than an assumption.

*Enforced by* §30.2 and §31.2 (`SortDairySenseRowsUseCase`), Phase 2.

### 33.2 Duplicate `(Date, Session)` across two input files — **ANSWERED: hard block**

Not warn-and-allow. The batch is rejected, naming **both** files, with no
"export anyway" override.

*Reason.* Unlike missing cows, there is no legitimate reading of "the same
milking session twice in one workbook" — it silently doubles a whole session in
the herd database. A clear message from us also beats DairySense's own
`"Hata: Subquery returns more than 1 row"`. This **reverses** the original
§30.4 default assumption; see §36.2 and **D6**.

*Enforced by* §30.4 and §30.9, Phase 2.

### 33.3 `MilkIntegration.exe` control identifiers — **STILL OPEN, owned by Phase 5S**

*Not answerable from here.* This is one of the six questions in §29.8 and it is
the biggest cost fork in the whole plan: if the window exposes child `HWND`s the
automation is Tier 1 (`user32` messaging, no COM); if it does not, it is Tier 2
(`IUIAutomation` through FFI, possibly with hand-written bindings).

*Rule adopted regardless of the answer:* never depend on the classic dialog
control IDs (`edt1`, `cmb13`) — they exist only on the legacy `GetOpenFileName`
dialog. Walk children by class name instead, which works on both dialog
generations. All Turkish UI strings (`Load Milk Data`, `Tamam`, `Hata`, the Open
dialog caption) live in **one** constants file and are treated as
locale-dependent.

*Resolved by* Phase 5S, whose Definition of Done is that §29.8 has a written,
dated answer per question **before** Phase 5 is designed. See **D12**.

### 33.4 License issuance workflow — **ANSWERED: offline request code + a repo CLI**

The app shows a copyable ~20-character request code derived from the four
fingerprint components plus the app version. The developer runs a companion Dart
CLI in this repo (`tool/license_cli/`) that shares the payload and signature code
with the app — so signer and verifier cannot disagree — and emails the resulting
`license.dat`. The user loads it with an in-app file picker that copies it into
the data root and re-evaluates immediately, with no restart.

*Reason.* Zero network in the app, consistent with §34; and sharing the signing
code with the verifier removes the classic "issued licenses the app rejects"
failure.

*Enforced by* §30.14 and §31.1, Phase 7.

### 33.5 Multi-date workbook acceptance — **STILL OPEN, and it BLOCKS Phase 2**

**Does DairySense accept one workbook containing more than one date?** Nobody has
tried. This is not a detail: `test/fixtures/README.md` records that the real
customer reports available (`Session1 8-8`, `Session2 7-8`, `session 3 7-8`) span
**two dates**, so the very first real batch a user runs is a mixed-date workbook.
If DairySense rejects it, the merge design becomes "one workbook per date" and
Phase 2's scope changes.

Verified with **no new code**: run the shipped v1.0 exe three times to produce
three single-session workbooks, then in Excel paste the data rows into one
workbook — preserving the exact `Sayfa1` sheet name, the 8 headers, `dd/mm/yyyy`
date cells and `hh:mm` time cells — and import that into the real DairySense.

Four acceptance cases, each recorded pass/fail **with the observed dialog text**:

- **H** — Is a two-date workbook accepted at all? Title `Tamam`, and does the
  reported record count equal the row count?
- **I** — Are records attributed to the correct date **and** session? Checked
  per-cow inside DairySense, not just by count. A silently-wrong attribution is
  worse than a rejection.
- **J** — Import the same workbook twice: duplicate, reject, or update? This
  decides whether §30.12's re-import guard is **absolute or advisory**, and it is
  the cheapest available answer to the idempotency question that the `unknown`
  outcome (§29.5) depends on.
- **K** — Deliberately include the same cow twice in one `(date, session)`: does
  it reproduce `"Hata: Subquery returns more than 1 row"`? That would confirm the
  importer enforces the rule and tell us what our own duplicate guard must
  prevent.

Recorded as acceptance cases H–K in
`specs/001-alpro-dairysense-converter/quickstart.md`, with the outcome and the
date written into `contracts/file-formats.md` — that file's stated job is
recording what was verified against real files and when.

*Gates* Phase 2 (and case **J** gates part of Phase 5).

### 33.6 History retention limits — **ANSWERED: two caps, and it always asks**

The original question asked whether "no TTL, no auto-purge" (§30.6) survives
months of daily use. It does not, unqualified: three sessions a day for a year is
roughly a thousand retained workbooks with no ceiling.

Answer: keep the last **N entries (default 60)** *and* cap **total bytes (default
200 MB)**, evicting oldest first — but **never delete without asking**, always
naming the entries and the space reclaimed, with current usage shown in the
History view. That keeps §30.6's substance (nothing disappears on its own) while
bounding growth, so it is a prompted cleanup rather than an auto-purge.

*Enforced by* §30.6 and §30.16, Phase 6. See **D14**.

## 34. Non-Goals for v1.1+ (reaffirmed / new)

**Carried over from Part 1 §10, still non-goals** — none of these is revisited by
any phase in §32: modifying Alpro or DairySense itself, cloud sync / login /
remote database, herd synchronisation, Alpro↔DairySense number mapping
(Constitution II), invented conductivity/temperature values, manual mapping
configuration.

**Carried over from §28's "Explicitly rejected", still rejected:** multiple farms
/ multiple cow lists. One farm, one list.

**Newly declared non-goals**, each because a phase above could otherwise be read
as implying it:

- **No network access of any kind.** Not for licensing (§33.4 is an offline
  request-code + emailed-file workflow), not for updates, not for telemetry, not
  for crash reporting. The support log (D9) is a local file the user chooses to
  send. "Local-first, no backend" from Part 1 survives v1.1+ intact.
- **No rollback of an external import.** Once `MilkIntegration.exe` has written to
  the herd database, Alfa Milk cannot undo it and will never claim to. This is why
  the `unknown` outcome exists, why cancellation after `path_submitted` is renamed
  **Stop waiting** (§30.11), and why the duplicate-session guard is a *block*
  rather than a warning (§33.2).
- **No cloud licensing, no license server, no online activation or
  deactivation.** Reissuing a license is a human step by the developer (§33.4).
- **No per-user data separation.** `%ProgramData%\AlfaMilk\` is machine-wide by
  design: one cow list, one history, one ledger, one license per computer. A
  second Windows account sees the same data. For a single-operator farm this is
  the desired behaviour, and it is what makes the data survive a reinstall under
  a different account (§30.15).
- **No editing of report data.** Nothing in the History page, the workbook
  inspector, or the import flow lets a user change a yield, a duration, a date or
  a session. The inspector is read-only; it reports, it never repairs.
- **No automatic deletion of anything.** No TTL, no silent purge, no
  uninstall-time data removal (§30.16, §30.6, §31.1). Every deletion is a
  confirmed user action.
- **No second executable and no .NET dependency.** Automation is in-process FFI
  (§29.4), so the build host stays Visual Studio 2022 + Flutter + Inno Setup.
- **No code signing certificate for v1.1+.** The installer ships unsigned and the
  SmartScreen click-through is documented instead (§32, Phase 1).

## 35. Definition of Done — roll-up across v1.1.0 → v1.8.0

**Each release has its own Definition of Done in its §32 phase entry, and that is the
gate for shipping it.** This section is the roll-up: the original v1.1 DoD kept
intact, with the release that satisfies each line named. Nothing here is a new
requirement; if a line and a phase entry ever disagree, the phase entry wins,
because that is the one being tested at release time.

- User can drag/select any number of Alpro HTML session files and get one
  merged DairySense XLSX, sorted deterministically, with all v1.0 business
  rules (filter-not-mapping, missing-cow confirmation spanning the batch,
  no fake rows, Conductivity/temperature = 0, folder chosen every time)
  still holding. — **Phase 2 (v1.2.0)**, drag & drop **Phase 3 (v1.3.0)**.
- User can click one button after saving the merged file and have it
  imported into DairySense via `MilkIntegration.exe` automatically, with a
  clear success/failure result shown in Alfa Milk — and a manual fallback
  always available if automation fails. — **Phase 5 (v1.5.0)**, preceded by
  **Phase 5S** (the spike). The manual fallback is now a named business rule
  (§30.13), not an implied courtesy, and the result set is four outcomes, not
  two (§29.5).
- Every conversion appears in History with enough detail to identify it
  later, is re-downloadable, and is deletable; History is exportable.
  — **Phase 4 (v1.4.0)** for the ledger, the History page, delete and the
  workbook inspector; **Phase 6 (v1.6.0)** for export and the retention cap.
- Cow-list updates are automatically backed up before being replaced.
  — **Phase 1 (v1.1.0)**, and it now includes the user-initiated **Restore
  previous list…** action that §30.7 promises (§36.1, item 9).
- The app ships as a proper Windows installer and refuses to run on a
  machine it wasn't licensed/activated for, without ever destroying local
  data if the license check fails. — installer **Phase 1 (v1.1.0)**,
  licensing **Phase 7 (v1.7.0)**. "Without ever destroying local data" is
  implemented literally by §30.15's fixed `%ProgramData%\AlfaMilk\` root and
  §30.8: a `blocked` app puts the activation screen *in front of* the data and
  deletes nothing, and uninstall never removes the data folder.
- The UI has been redesigned (clean, professional, agricultural) with a
  working dashboard and dark mode, built around the finished functional
  features above — not before them. — **Phase 8 (v1.8.0)**. The structural
  half (the `NavigationRail` shell) arrives early in Phase 4 because the
  History page needs it; that is deliberate, not scope creep.

Two release-wide conditions apply to every phase and are not repeated in each
entry: `flutter analyze` is clean and `flutter test` is green on Linux before any
Windows work, and every item is written test-first (Constitution V).

## 36. Feature & Rule Traceability (Requirement 2 — nothing disappears silently)

**Purpose.** §27–§35 originally described 14 features, 8 business rules, a module
tree, 5 open questions and a non-goals list. This section accounts for **every
one of them** — kept, redesigned, moved, or explicitly deferred — with the phase
that delivers it. It is a checklist against silent loss: if a future edit drops a
feature, the row here is left without a home and the omission is visible in review
rather than discovered on the farm.

**Rule for future edits:** never delete a row. If something is genuinely
abandoned, change its disposition to *dropped* and write the reason in the row.

### 36.1 §28's 14 features

§28's header originally said "13 items" while listing 14 (**D13**); dark mode is
#14. The count is fixed in §28.

| §28 | feature | disposition | phase |
|---|---|---|---|
| 1 | Multi-session merge | **Kept**, redesigned: per-report pipeline then concatenate rows (§31.2) instead of concatenating `AlproRecord`s | 2 (v1.2.0) |
| 2 | One-click DairySense import | **Kept**, re-architected in-process (Dart FFI, no helper exe) — §29.4 | 5 (v1.5.0) |
| 3 | Drag & drop | **Kept as-is**, now multi-file since Phase 2 makes selection a list | 3 (v1.3.0) |
| 4 | Live progress panel | **Kept** — `SendPort` progress, §31.3. Its "merged with preview before export" half is delivered by the single-parse `ConversionPlan` (**D1**): the confirm dialog describes an object that already exists, which is why the counts are free | 3 (v1.3.0); D1 in 2 |
| 5 | Implausible cow-number warning | **Kept, moved** from conversion output to cow-list import (**D4**) — the number is caught where it enters the system, once, instead of warning on every conversion forever. §28's "never silently drops or corrects the number" is preserved unchanged | 1 (v1.1.0) |
| 6 | Conversion History | **Kept and enlarged** — a real page (list + detail), plus the workbook inspector. §28's "re-imported later without redoing the conversion" becomes an explicit **Import into DairySense** action on the entry detail | 4 (v1.4.0) |
| 7 | Delete from History | **Kept, moved earlier** — ships with the page it belongs to; a list you cannot prune grows to a thousand rows | 4 (v1.4.0) |
| 8 | Export History to Excel or PDF | **Kept, deferred**, unchanged in scope | 6 (v1.6.0) |
| 9 | Automatic cow-list backup | **Kept, split.** The automatic `.bak` is the atomic-write sequence (§30.7) — same few lines. The **user-initiated restore is a separate thing**: the `.bak` fallback fires only on corruption, so a *valid but wrong* list would overwrite the good one with nothing offering it back. A **Restore previous list…** button on `CowListCard` (shows the backup's cow count + timestamp, asks, then swaps) is therefore part of the same phase | 1 (v1.1.0) |
| 10 | Professional installer | **Kept, moved to first** — shipping to a machine you do not control demands durability before features | 1 (v1.1.0) |
| 11 | Hardware-locked licensing | **Kept, redesigned to hard lockout** — two states, strict all-four fingerprint, `evaluationError` self-heals via **Check again** (§30.14) | 7 (v1.7.0) |
| 12 | UI redesign | **Kept, deferred** — but partly pre-empted: the `NavigationRail` shell is the structural half and arrives in Phase 4 because History needs it | 8 (v1.8.0) |
| 13 | Dashboard home screen | **Split.** The dashboard is Phase 8. Its **~30-day cow-list staleness warning moves to Phase 1**: the nullable-`lastUpdated` fix (§30.7 / **D2**'s sibling) was justified *by* this warning, so shipping the fix without it leaves it with no consumer, and "unknown age ⇒ treat as stale" is only observable if something warns | staleness 1; dashboard 8 |
| 14 | Dark mode | **Kept, deferred**, unchanged in scope | 8 (v1.8.0) |

**§28's explicit rejections stay rejected** — no cloud sync, no login, no remote
database, no Alpro↔DairySense number mapping (Constitution II), no multiple farms
or multiple cow lists. See §34.

**Added, and in neither §28 nor Part 1:** the workbook inspector (§31.1), the
`NavigationRail` shell, the `%ProgramData%` data root + copy-migration (§30.15),
the support log (**D9**), the single-instance guard (**D8**), temp-then-rename
workbook writes (**D11**), and acceptance cases H–K (§33.5).

### 36.2 §30's original 8 business rules

| original | rule | disposition | now |
|---|---|---|---|
| 1 | Merge preserves each record's own Date/Session | **kept verbatim** — and now structurally guaranteed: rows are stamped per report by the existing use case, so no code path can produce an unstamped row | §30.1 |
| 2 | Deterministic row order in the merged workbook | **kept + extended** — the ordering left open is answered: date → session → insertion index, with the third key explicit because Dart's `List.sort` is not stable | §30.2, §33.1 |
| 3 | Missing-cow confirmation spans the whole batch | **kept as the blocking gate** — and the per-day/per-session breakdown is added as *non-blocking* detail, recovering the information the batch-wide-only rule was discarding, without making the gate fire on every real batch | §30.3 |
| 4 | Duplicate `(Date, Session)` across files | **REVERSED** — was warn-and-allow, is now a hard block naming both files, no override. Unlike missing cows there is no legitimate reading of "the same milking twice in one workbook", and it silently doubles a session in the herd database (**D6**) | §30.4, §30.9, §33.2 |
| 5 | Auto-import never replaces the ask-every-time save step | **kept verbatim** | §30.5 |
| 6 | No auto-purge, no TTL for history | **refined, substance kept** — a count cap and a byte cap are added, but they **always ask before deleting** and always show what would be removed. That keeps "nothing disappears on its own" true while bounding growth: a prompted cleanup, not an auto-purge (**D14**) | §30.6, §30.16, §33.6 |
| 7 | Cow list backed up before replacement | **kept, and now actually implemented** — the atomic write produces the `.bak`, and **Restore previous list…** makes it reachable | §30.7 |
| 8 | A license failure never destroys local data | **kept, reconciled with hard lockout** — "never destroys" is about *deletion*, and `blocked` deletes nothing: it renders the activation screen in front of untouched data in a folder the installer never removes | §30.8, §30.15 |

**New rules 30.9–30.16** (fail-whole-batch-and-name-the-file; unparsable date
rejects the batch; `timeout ≠ failure` with `path_submitted` as the boundary;
re-import guarded by workbook hash; non-success import always offers the workbook;
two license states; one fixed install-independent data root with no silent
fallback; retention never deletes without asking) are additions, not replacements.

### 36.3 §31's module tree

| original entry | disposition | reason |
|---|---|---|
| `MergeReportsUseCase` | **renamed → `SortDairySenseRowsUseCase`** | what is merged is *rows*, not reports; there is no report-level merge step to own |
| "Parser/writer extended to accept `List<String> htmlPaths`" | **dropped** | the parser stays single-file and is called N times — that is precisely what makes the plan's own claim "the three v1.0 use cases are reused unchanged" true |
| "Concatenate `AlproRecord`s with their source Date/Session before filtering" | **dropped, corrected** | `AlproRecord` carries no date or session, so that concatenation destroys provenance; §31.2 inverts it |
| `history_store.dart` (JSON index) | **kept, redesigned** — one file per entry, no index | a single rewritten index file is corruptible and desynchronises from the retained workbooks (**D10**) |
| `windows_ui_automation_client` | **kept, narrowed** — FFI only, no process bridge | §29.4's in-process decision |
| batch entities, batch repo method, progress channel | **kept** | §31.2, §31.3 |
| — | **added:** `DairySenseReader` (inspector), the `shell/` rail module, `app_data_dir.dart`, `write_json_atomic.dart`, `support_log.dart`, the licensing module, the FFI import service, `tool/license_cli/`, and the new failure types | each traced to a decision above |

Components explicitly **unchanged from v1.0** are listed in §31.5; that list is
part of the traceability, because "unchanged" is a claim tests must keep true.

### 36.4 §33's questions and §34's non-goals

| original | answer / status | enforced by |
|---|---|---|
| Q1 merged-row ordering | date → session → insertion index | §30.2, §33.1, Phase 2 |
| Q2 duplicate `(Date, Session)` | hard block, both files named | §30.4, §33.2, Phase 2 |
| Q3 control identifiers | **still open** — owned by Phase 5S; Tier 1/Tier 2 decided by what it finds; classic control IDs never trusted | §33.3, **D12** |
| Q4 license issuance | offline request code + `tool/license_cli`, signer shares code with verifier | §30.14, §33.4, Phase 7 |
| Q5 history retention | count cap + byte cap, always prompted | §30.6, §30.16, §33.6, Phase 6 |
| *(new)* multi-date acceptance | **still open and blocking** — acceptance cases H–K | §33.5, gates Phase 2 |

| non-goal | status |
|---|---|
| Part 1 §10's six non-goals (modify Alpro/DairySense, cloud sync/login/DB, herd sync, number mapping, invented conductivity/temperature, manual mapping config) | **all still non-goals**, none revisited by any phase |
| multiple farms / multiple cow lists (§28's rejection) | **still rejected** |
| no network of any kind; no rollback of an external import; no cloud licensing; no per-user data separation; no editing of report data; no automatic deletion; no second executable / .NET dependency; no code signing certificate | **newly declared** (§34) |

## 37. Defect Register D1–D15 (Requirement 3)

**Purpose.** These are the defects the two independent reviews of §27–§35 found —
in the v1.0 code and in the v1.1 plan itself. They are recorded here, in the plan,
so they survive the conversation that produced them. Each is also named in its
phase's **Defects addressed** line in §32; the two views must not drift.

Evidence cites the file and line as of v1.0.0. If a line number stops matching,
the evidence is stale, not the defect — re-locate it before assuming it is fixed.

| # | Problem | Evidence | Fix | Phase |
|---|---|---|---|---|
| **D1** | **Double-parse / TOCTOU.** The preview parses the report, then the convert call re-runs the whole pipeline including a second parse. Between the two: the missing-cow dialog **and the native save dialog** — a file browser in which the source can be renamed, moved or overwritten. The user confirms missing cows for file A and converts file B; the dialog was a lie. The window is unbounded in user time, not a tight race | `report_convert_view.dart:54-56` (preview parse), `:80` (missing-cows dialog), `:93` (save dialog), `:100-104` (re-parse) | Parse **once**: the preview produces an immutable `ConversionPlan` held by the cubit; the confirm dialog describes that object; the write step consumes it and never re-parses. Halves parse cost and is a prerequisite for progress reporting. Belt-and-braces: record each source file's SHA-256 in the plan and re-verify before writing → `SourceChangedFailure` naming the file. Also fixes `_preview()` (`:134-143`) constructing use cases inline instead of using the repo's | 2 |
| **D2** | **Failure-taxonomy leak.** Every unanticipated failure — disk full, permission denied, isolate crash — is reported to the farmer as an Alpro *parse* problem, with the raw exception text interpolated into the message, which Constitution IV forbids | `conversion_repo_impl.dart:71-73` | `UnexpectedFailure` with a fixed user-facing sentence and **no interpolated exception**; raw text to the support log (D9). Add `BatchParseFailure`, `ImportFailure`, `ImportUnknownOutcomeFailure`, `LicenseFailure` so each subsystem maps to its own type. Standing rule: no `$e` inside any `Failure` construction | 1 |
| **D3** | **Cancellation does not cancel.** `reset()` merely emits the initial state. Harmless today; once the button drives an external program, "Cancel" would return the UI to idle while `MilkIntegration.exe` keeps writing to the herd database | `conversion_cubit.dart:23` | Two honest mechanisms. **(a) Conversion:** `reset()` valid only from initial/success/failure; no mid-run cancel unless `Isolate.spawn` + `kill()` is adopted (deferred, and paired with D11). **(b) Import:** a flag checked between polls — before `path_submitted` kill the launched process → `precondition_failed`; after it the button becomes **Stop waiting** and the outcome is `unknown`, never `cancelled` | 3 / 5 |
| **D4** | **Implausible-cow-number check in the wrong place.** §28 put it on conversion output. By then the bad number is already in the list, already filtered against every report, already silently matching nothing — and the user is warned on every conversion forever instead of once | §28 item 5 | Move to **cow-list import**, where the number enters the system and the user is already reviewing the list. Validate range and digit count, show the suspects, let the user accept or fix, then persist. Conversion stays silent | 1 |
| **D5** | **Mixed Date cell types in a merged workbook.** `_dateValue` returns `DateCellValue` when the date parses and `TextCellValue` when it does not. In one session that is merely odd; merged, a single Date column can hold both types, and a consumer reading a typed column may mis-read or reject the file. The upstream mechanism is a missing date becoming `''` | `dairy_sense_writer.dart:94-98`, `alpro_parser.dart:84` | The batch pre-flight rejects the whole batch if any report's date is unparsable, naming the file — so a merged workbook can only ever contain `DateCellValue`. Keep the `TextCellValue` branch for the single-file path, plus a test asserting a merged workbook's Date column is uniformly typed. Same reasoning for the empty-session guard: `''` collides in the duplicate key | 2 |
| **D6** | **Duplicate `(date, session)` in one batch** — the user picks Session 2 twice, or two exports of the same session under different filenames. Silently doubles a whole milking | §30.4 as originally written (warn-and-allow) | Hard block in the batch pipeline, naming **both** files, no override. If H–K shows DairySense rejects it too, keep our block anyway: a clear message from us beats `"Hata: Subquery returns more than 1 row"` | 2 |
| **D7** | **Re-import of an already-imported workbook.** Nothing today knows an import happened, so nothing can stop a second one | no ledger exists in v1.0 | Ledger lookup by workbook SHA-256 before the import button enables: `success` → block, naming records and date, with an explicit override; `unknown` → warn hard, no one-click retry; `failure` → allow. Case **J** decides absolute vs advisory | 5 |
| **D8** | **Concurrency: nothing prevents two conversions or two imports at once.** Buttons are disabled only while the state is `ConversionLoading`, so a double-click during a modal — or two app instances — both proceed. Two simultaneous imports into one herd database is the worst case | `report_convert_view.dart:158,163,178` | Disable on **any** non-idle state. Single-instance guard at startup (named mutex / lock file with a stale-PID check) that focuses the existing window. An advisory lock around the import step, released in a `finally` | 3 / 5 |
| **D9** | **No support log.** When something fails on the farm's machine the only artefact is a sentence on screen — and Constitution IV correctly forbids showing the raw error, so the raw error is simply lost. Hard lockout raises the stakes: the developer becomes the only route back to a working app | — | Rolling `<dataRoot>/log/alfa_milk.log`, size-capped (~5 × 1 MB): timestamps, app version, phase, raw exception + stack, every Win32 step with its `HWND` and `GetLastError()`, license state and block reason, and fingerprint **component names only, never values**. The activation screen gets a copy-to-clipboard version that works while blocked; the zip export comes later | log 1; zip 6 |
| **D10** | **History storage crash-consistency.** A single `history.json` rewritten on every change is corruptible and desynchronises from the retained workbook files | planned `history_store.dart (JSON index)` | One JSON file per entry, atomic writes, **no index**, directory enumeration for listing, workbook-then-entry delete order, startup orphan sweep | 4 |
| **D11** | **Workbook written in place.** The writer writes straight to the user's chosen path, so a crash, a full disk, or a killed isolate mid-write leaves a corrupt file **at the path the user believes holds their data** — and if it overwrote yesterday's export, that is gone too | `dairy_sense_writer.dart` write path | Write `<target>.partial` in the same directory, then rename onto the target. Prerequisite for any future mid-conversion cancellation | 2 |
| **D12** | **§29's UNKNOWNs are unresolved and load-bearing:** whether the window exposes child `HWND`s at all (Tier 1 vs Tier 2 — the biggest cost fork in the feature), the control classes, whether multiple instances coexist, behaviour with DairySense's main app open, whether the exe is elevated, whether `...\Debug\...` survives a vendor update. The plan scheduled implementation as if these were known | §29 as originally written | The Phase 5S spike, on the real machine, **before** Phase 5 is designed. Output is a written, dated answer per unknown appended to §29 — **not shipped code**. All Turkish UI strings centralised in one constants file and treated as locale-dependent | 5S |
| **D13** | **§28 says 13 items and lists 14** | §28 header | Count fixed; dark mode is #14. Recorded here so a future reader does not "fix" it back | doc |
| **D14** | **Retained-workbook disk growth is unbounded.** A 147-record workbook is small, but three sessions a day for a year is roughly a thousand files with no ceiling | §30.6 as originally written | Keep the last N (default 60) **and** cap total bytes (default 200 MB), oldest first, **always asking**, showing current usage in the History view | 6 |
| **D15** | **Missing dependencies for the planned features.** `pubspec.yaml` has none of what v1.1+ needs | `pubspec.yaml` | Add **per release, not up front**: `cryptography` (Ed25519) Phase 7; `crypto` (workbook hashing) Phase 4; `desktop_drop` Phase 3; **`win32` + `ffi`** Phase 5; a PDF package Phase 6. Build-host prerequisites recorded next to the existing VS2022 note: **Inno Setup** only — the in-process FFI decision *removes* the .NET SDK prerequisite a helper-exe design would have added | per phase |

### Positions carried forward from the review (not defects, but decisions with reasons)

- §30.3's batch-wide-only missing rule **did** lose information: a cow that milks
  in session 1 but not 2–3 is flagged twice under v1.0 and zero times under a
  batch-wide-only rule. §30.3's non-blocking breakdown restores it without making
  the blocking gate noisier.
- The plan's assumption that the three v1.0 use cases can be reused unchanged is
  **true** — but only under the per-report design. §31's original
  concatenate-records phrasing made it false.
- `MilkIntegration.exe` automation is not a UI feature. It is this app acquiring
  write access to the herd database through a third-party process it does not
  control. That is why it has business rules in §30 rather than only an
  architecture note in §31.