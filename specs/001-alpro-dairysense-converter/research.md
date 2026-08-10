# Research: Alpro → DairySense Converter

**Date**: 2026-08-09
**Goal**: Resolve the technology/format unknowns for the plan. Every decision below
is chosen to keep the implementation simple enough for a low-budget LLM
implementer: few files, few packages, no metaprogramming, no exotic APIs.

---

## 1. HTML Parsing

- **Decision**: Use the `html` package (pub.dev, publisher `dart-lang`).
- **Rationale**: Official Dart HTML5 parser. Simple API: `parse(String)` returns
  a `Document`; `document.querySelectorAll('table')` and cell text via
  `element.text.trim()`. No regex, matches Constitution Principle VI.
- **Alternatives considered**:
  - Manual regex/extraction — rejected: fragile, violates Principle VI.
  - `cascadia` (CSS selectors) — rejected: extra dependency, `querySelectorAll`
    on the generic `Element` API is enough.

## 2. Excel Read + Write

- **Decision**: Use the `excel` package (pub.dev pkg `excel`, justkawal, v4.x).
- **Rationale**: One package reads XLSX (cow list) AND writes XLSX (DairySense
  output). Pure Dart, no native toolchain. Cell values in v4 are `CellValue`
  subclasses (`TextCellValue`, `IntCellValue`, `DoubleCellValue`, ...) —
  implementer must convert to plain values with a small helper.
- **Alternatives considered**:
  - `spreadsheet_decoder` — reads only; would need a second writer package.
  - `excel_plus` / `excel_community` — newer forks; `excel` has the most
    documentation and examples. One common package is easier for a cheap model.

## 3. File / Folder Dialogs (Windows)

- **Decision**: Use the `file_picker` package (v11, static API).
- **Rationale**: Single API for all three needs: pick HTML file
  (`FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['html'])`),
  pick cow-list Excel (`['xlsx']`), and save the output
  (`FilePicker.saveFile(...)` with an editable default file name — this
  satisfies FR-015 "user MUST be able to edit the file name" with NO custom
  dialog code). In v11 these are static methods on `FilePicker`, not
  `FilePicker.platform.*`.
- **Alternatives considered**:
  - `file_selector` (flutter.dev) — also fine; `file_picker` is more common in
    examples, which helps a cheap model.

## 4. Persistence

- **Decision**: A single JSON file at
  `getApplicationSupportDirectory()/cow_list.json` via `path_provider` +
  `dart:convert` + `dart:io`. No database.
- **Rationale**: One active cow list, a few thousand ints max — a JSON file is
  simpler, debuggable, and survives restarts/reboots (Constitution Principle I).
- **Alternatives considered**:
  - `shared_preferences` — stores strings fine, but JSON file via path_provider
    is equally simple and keeps the pattern of direct file IO the app already
    uses for reading inputs.
  - SQLite (`sqflite`/`drift`) — rejected: overkill, native plugin, heavier
    setup for one list.

## 5. Concurrency / UI Responsiveness (FR-018)

- **Decision**: Run the whole conversion (parse → filter → transform → write
  workbook) inside one `await Isolate.run(() => ...)` call from the UI button
  handler. `dart:io` files are copied into the isolate and the result object is
  returned.
- **Rationale**: One line of API, nothing to manage. UI stays responsive for
  thousands of records. The pipeline function is already pure/returnable, so it
  is isolate-friendly.
- **Alternatives considered**:
  - `compute()` — same thing but works only on web-safe functions; on Windows
    `Isolate.run` is the documented simple form.
  - Manual `Isolate.spawn` + ports — rejected: error-prone, no benefit here.

## 6. Cow-Number Normalization (FR-005)

- **Decision**: Trim the cell string; if it parses as int → use it; else if it
  parses as double with zero fraction (e.g. `5.0`) → use `toInt()`; else the
  value is invalid. All comparisons happen on `int`.
- **Rationale**: Makes `07`, `7`, `5.0` all equal. Int keys behave trivially in
  `Set<int>` / `Map<int, ...>`.
- **Alternatives considered**: String normalization (`007` → `7` by stripping
  leading zeros) — rejected: `5.0` would slip through; int parsing is stricter
  and simpler to test.

## 7. Cow-List Column Detection (FR-004)

- **Decision**: Read the first non-empty row as the header row. Normalize each
  header (trim, lowercase, remove non-letters/digits, e.g. `Cow Number` →
  `cownumber`). First header that equals/starts with `cownum` or `cow` wins.
  Fallback: first column that contains at least one valid numeric value;
  surface a notice to the user when the fallback is used.
- **Rationale**: Covers "Cow Number", "Cow No.", "CowNumber", "Cow no." without
  a fragile exact-match table. Fallback keeps FR-004 behavior.
- **Alternatives considered**: Configurable column — rejected (out of scope,
  adds UI).

## 8. Alpro Report Structure (unknown until fixture arrives)

- **Decision**: The authoritative Alpro HTML sample file is NOT in the repo yet.
  The parser contract (see `contracts/file-formats.md`) defines the expected
  structure from the spec: a table whose header row contains `Cow No.`,
  `MPC Address`, `Milk Yield`, `Milk Dur.`, plus report-level `Date` and
  `Session` values elsewhere in the document.
- **When the real file is provided** (place at `test/fixtures/alpro_report.html`),
  the implementer MUST inspect it and adjust the header-name map and the
  Date/Session search labels in `alpro_parser.dart` until the integration test
  passes. The contract file documents where to look and how to adjust.
- **Alternatives considered**: Guessing exact markup now — rejected
  (Constitution Principle VI: never invent formats).

### Implemented for the real Alpro reports (2026-08-10)

The real files use a header cell `Cow No.` that includes a trailing sort
indicator (renders as `cowno1`), so required headers are matched by **prefix**
(`_headerMatches`). Report-level `Date`/`Session` have no `Date:`/`Session:`
labels; instead a **pattern** extractor reads the date token (`26.08.08`) and
the active session number from "Session N" in the title (`1`/`2`/`3`),
with label-based extraction retained as a fallback. Dry-cow rows
(`Milk Yield 0` / `Milk Dur. -`) are kept and exported as `0` rather than
skipped.

## 9. DairySense Output Workbook

- **Decision**: One sheet, first row = the 8 required headers
  (`Date`, `Session`, `UnitNo`, `CowNumber`, `Milking Time`, `Milk yield`,
  `Conductivity`, `temperature`), one data row per Alpro record. `Conductivity`
  and `temperature` written as numeric `0`. All values written as plain
  `String`/`int`/`double` per column.
- **Rationale**: The `excel` package writes a standard XLSX that import tools
  read. Column names and order are fixed by FR-012; verify against the real
  DairySense template (`test/fixtures/dairy_sense_template.xlsx`) when it
  arrives and adjust sheet name/header row if needed.
- **Alternatives considered**: Heavy styling/formatting — rejected: plain cells
  are what the import tool needs; the template verification step covers
  column-level details.

## 10. Output File Name (FR-015)

- **Decision**: Default `DairySense_Import_<YYYY-MM-DD>_<H.mm am/pm>.xlsx`
  (time of conversion, **12-hour** am/pm, e.g.
  `DairySense_Import_2026-08-10_11.13 am.xlsx`) offered through the native save
  dialog; the user can edit it there. If writing fails (file exists / locked /
  read-only), the app shows a friendly "could not be saved" message and re-opens
  the save dialog to retry.
- **Rationale**: Timestamped default avoids mostly the collision case; the save
  dialog makes the name editable with zero custom UI. Cancelling the save dialog
  (or the missing-cow dialog) resets the cubit so `CONVERT` is immediately
  re-enabled, no file is created, and no dialog is shown.