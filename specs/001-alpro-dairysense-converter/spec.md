# Feature Specification: Alpro → DairySense Converter

**Feature Branch**: `001-alpro-dairysense-converter`

**Created**: 2026-08-08

**Status**: Draft

**Input**: User description: "create specification and look at docs/alpro_dairysense_plan.md and constitution; make everything best practice"

## Clarifications

### Session 2026-08-08

- Q: When the Alpro report and the cow list express the same cow number
  differently (e.g., `07` vs `7`), should they still match? → A: Yes —
  numeric equivalence after trimming (FR-005).
- Q: If the Alpro report contains several milking rows for the same cow,
  how should the output treat them? → A: One output row per Alpro record —
  every milking event is preserved, never merged or dropped (FR-009).
- Q: If the conversion ends with zero matching records, should the app
  still create an output file? → A: No — no file is created; the app
  explains and the user fixes inputs (FR-021).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Convert a milking report into a DairySense import file (Priority: P1)

The user (herd manager or farm worker) launches the app, selects an Alpro HTML
milking report, and converts it into a DairySense-ready Excel file containing
only the cows on the current DairySense cow list.

**Why this priority**: This is the core purpose of the app — delivering a
correct, ready-to-import milk data file from an Alpro report. Everything else
exists to make this safe and repeatable.

**Independent Test**: Pick a sample Alpro report and a cow list, run the
conversion, and verify the output workbook contains exactly the matching
records with the correct columns and values.

**Acceptance Scenarios**:

1. **Given** a valid Alpro report with all required columns and a saved cow
   list, **When** the user converts, **Then** the output contains only records
   for cows on the list, no records for cows not on the list, and nothing else.
2. **Given** no cow list has ever been saved, **When** the user starts a
   conversion, **Then** the app explains that a cow list is required, asks the
   user to import one, and does not export anything.

---

### User Story 2 - Trust the current cow list (Priority: P1)

The user imports a new cow-list Excel whenever the herd changes. The app
validates it, saves it locally, and automatically reuses the last saved list
on later runs. A failed import must never remove the previously valid list.

**Why this priority**: The cow list is the source of truth that prevents
exporting the wrong animals. Losing it would make conversions unreliable.

**Independent Test**: Import a valid list, restart the app, and confirm the
same list is still active; then import an invalid file and confirm the old
list is still used.

**Acceptance Scenarios**:

1. **Given** a valid cow-list file, **When** the user imports it, **Then** it
   becomes the current list and remains in use after an app restart.
2. **Given** an active cow list and an invalid new list, **When** the user
   attempts the update, **Then** the update is rejected, the problem is
   explained, and the previous list stays active.
3. **Given** a cow list containing duplicate numbers, **When** it is imported,
   **Then** duplicates are removed internally and the importer continues.

### User Story 3 - Never lose track of missing cows (Priority: P1)

If some cows on the active list are absent from the Alpro report, the user is
shown exactly which ones and asked how to proceed. Choosing to cancel produces
no output file; choosing to continue exports only the cows that were found.

**Why this priority**: Silently exporting a partial set would mislead the
herd data — the highest-cost failure for this app.

**Independent Test**: Convert with a list containing a cow absent from the
report; verify the missing cow is shown, Cancel produces no file, and
Continue produces a file without that cow.

**Acceptance Scenarios**:

1. **Given** a list where one cow is missing from the report, **When** the
   user confirms continue, **Then** the output contains all found cows and
   never a fake or empty row for the missing one.
2. **Given** the same situation, **When** the user cancels, **Then** no output
   file is created anywhere.
3. **Given** every cow on the list is present in the report, **When** the user
   converts, **Then** conversion proceeds without a missing-cow prompt.

### User Story 4 - Choose where files go, every time (Priority: P2)

After a successful conversion the user is always asked to pick the output
folder; the app never silently writes to Downloads, Desktop, Documents, or its
own folder.

**Why this priority**: Predictability and control over where sensitive farm
data lands.

**Independent Test**: Run a successful conversion and confirm the folder
picker appears every time, and the file lands only in the chosen folder.

**Acceptance Scenarios**:

1. **Given** a successful conversion, **When** the output step starts,
   **Then** the user is prompted to choose a folder before the file is saved.
2. **Given** the chosen folder is not writable or the file is already open,
   **When** the app tries to save, **Then** the user sees a clear, friendly
   message and can retry; no data is corrupted.

---

### Edge Cases

- What happens when the selected file is not a real Alpro report?
- What happens when required columns are missing from the report?
- What happens when the cow list has no valid numbers or is empty?
- What happens when saved cow-list data on disk is corrupted?
- What happens when the app is closed mid-conversion?
- What happens when two cows share the same number (duplicates in either input)?
- What happens when the report contains a cow whose number format differs
  from the list (whitespace, leading zeros)?
- What happens when the output file already exists with the same name?
- What happens when the destination is read-only, locked, or unavailable?
- What happens when the report is extremely large (thousands of records)?
- What happens when values that must be converted are missing or invalid?
- What happens on the very first run, before any cow list exists?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST accept one Alpro HTML report file selected by the
  user.
- **FR-002**: The app MUST parse all records in the report by locating the
  data table and identifying columns by their headers.
- **FR-003**: The app MUST extract at minimum: `Date`, `Session`, `Cow No.`,
  `MPC Address`, `Milk Yield`, `Milk Dur.` from the report.
- **FR-004**: The app MUST accept an optional cow-list Excel file, treated
  strictly as a filter — never as a number-to-number mapping. The cow-number
  column MUST be identified automatically by recognizing a header such as
  "Cow Number" (case-insensitive, with reasonable variants). If no
  recognizable header is found, the app MUST fall back to the first used
  column and inform the user of that assumption.
- **FR-005**: The app MUST normalize cow numbers consistently across report
  and list (removing surrounding blank space, duplicates, and preserving
  numeric identity), matching by cow number with row order irrelevant.
  Matching MUST use numeric equivalence: representations such as `07`,
  `007`, or `5.0` are treated as the same cow as `7` or `5` after trimming;
  only the numeric value determines identity.
- **FR-006**: The app MUST save the last successfully imported cow list
  locally, and MUST load it again after app restarts or device restarts.
- **FR-007**: When no new list is supplied, the app MUST use the last saved
  list automatically.
- **FR-008**: When a new list fails validation, the app MUST keep the previous
  valid list and explain the problem.
- **FR-009**: The app MUST export only records whose cow number is in the
  current list. Output cardinality is one-to-one: every parsed Alpro record
  for a selected cow MUST become exactly one output row; distinct milking
  events of the same cow are preserved, never merged or dropped.
- **FR-010**: The app MUST detect selected cows missing from the report, show
  them, and require explicit confirmation before continuing.
- **FR-011**: If the missing-cow warning is dismissed, the app MUST NOT create
  any output file; fake or empty rows MUST NEVER be created for missing cows.
- **FR-012**: The app MUST generate a DairySense-format workbook containing
  exactly the columns `Date`, `Session`, `UnitNo`, `CowNumber`,
  `Milking Time`, `Milk yield`, `Conductivity`, `temperature`, and MUST write
  `Conductivity` and `temperature` as `0`.
- **FR-013**: The app MUST derive `Date` and `Session` from the report — never
  from the computer's clock — and MUST NOT hard-code a session value.
- **FR-014**: The app MUST convert `Milk Dur.` from `HH:MM:SS` to total
  seconds. If a selected cow's `Milk Dur.` or `Milk Yield` is missing or
  invalid, the app MUST skip that record, list it in the conversion summary
  as a warning, and never guess a value.
- **FR-015**: The app MUST prompt for the output folder on every conversion.
  The output file MUST default to a time-stamped name
  `DairySense_Import_YYYY-MM-DD_HHmmss.xlsx`; the user MUST be able to edit
  the file name before saving, with a warning if the edited name collides
  with an existing file or is invalid.
- **FR-016**: The app MUST show a clear summary after conversion: report
  records, selected cows, cows found, and cows missing.
- **FR-017**: The app MUST handle output failures (no permission, invalid
  destination, file open, duplicate names, invalid filename) with clear
  messages and MUST NOT expose raw stack traces to the user.
- **FR-018**: The app MUST complete conversions of reports with several
  thousand records without making the UI appear frozen.
- **FR-019**: The app MUST NOT modify the Alpro report or the cow-list file,
  and MUST NOT synchronize any data to a network service.
- **FR-020**: The app MUST NOT depend on a fixed cow-count limit; the list
  size may change at any time.
- **FR-021**: The final workbook MUST NOT be created until all validation
  passes; the app MUST NOT write partial data. If zero matching records
  remain after filtering (no selected cow found, or all records skipped),
  the app MUST NOT create an output file; it MUST explain the situation and
  let the user fix the inputs and retry.

### Key Entities *(include if feature involves data)*

- **Alpro Report**: The source milking report (HTML). Contains records for
  all milking events with columns such as `Cow No.`, `MPC Address`, `Milk
  Yield`, `Milk Dur.`, and report-level `Date` and `Session` values.
- **Cow List (Current DairySense List)**: The active set of cow numbers that
  filters the report. Has a last-updated timestamp. Single persisted copy;
  one active list at a time.
- **Alpro Record**: One row parsed from the report (cow number + milking
  measurements).
- **DairySense Output Row**: One export row: `Date`, `Session`, `UnitNo`,
  `CowNumber`, `Milking Time` (seconds), `Milk yield`, `Conductivity` = 0,
  `temperature` = 0.
- **Conversion Result**: The outcome of a conversion: found/missing counts,
  warnings, and the saved output file path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A conversion of ~150 records completes correctly, from
  selecting the report to choosing the folder, in under 2 minutes.
- **SC-002**: 100% of records parsed from the supplied test report are
  available to filter; only cows on the active list ever appear in output.
- **SC-003**: Every output workbook opened in the target import tool with 8
  required columns in the specified order, `Conductivity`/`temperature` hold
  `0`, and all durations are total seconds.
- **SC-004**: 100% of conversions with missing cows present a confirmation
  prompt before any file is written; cancel never produces a file.
- **SC-005**: A failed cow-list import leaves the previous list active in
  100% of attempts.
- **SC-006**: The UI remains responsive for a report of around 5,000 records
  (no freeze perceived by the user).
- **SC-007**: Automated tests (using the supplied real files as fixed
  regression fixtures) pass 100% of conversion-rule cases before each release
  is considered fit.

## Assumptions

- The cow list is always the filter, never a mapping (see constitution,
  Principle II).
- The app is local-first and offline-only; no network, login, or cloud
  components (constitution, Principle I).
- Windows desktop is the primary and initial target platform; other desktop
  platforms are not required for the MVP, and mobile is out of scope.
- The supplied real files — an Alpro report, a cow-list workbook, and a
  DairySense import template — are the authoritative fixtures; the app MUST be
  verified against those exact files, and their exact structure will be
  inspected during planning (constitution, Principle VI).
- Cow numbers are integer-like; alphanumeric IDs are out of scope for MVP
  unless found in the supplied files.
- Milking durations are expressed as `HH:MM:SS` strings.
- Conductivity and temperature are written as literal `0` and are never
  derived or estimated.
- The saved cow list is stored inside the app's own local storage, with no
  cloud copy.
- Drag-and-drop selection, filtered-preview, conversion history, multiple
  farm profiles, and editable mappings are explicitly out of scope for the
  MVP (constitution, Non-Goals).

## Resolved Decisions

1. Cow-number column in the cow-list Excel: auto-detect by header
   ("Cow Number", case-insensitive), falling back to the first used column
   with a user notice. (FR-004)
2. Missing/invalid `Milk Dur.` or `Milk Yield`: skip the record, warn in the
   conversion summary, never guess. (FR-014)
3. Output file name: default `DairySense_Import_YYYY-MM-DD_HHmmss.xlsx`,
   user-editable before save. (FR-015)