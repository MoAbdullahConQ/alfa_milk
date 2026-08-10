# Contracts: File Formats

**Date**: 2026-08-09
**Purpose**: The three external file formats the app touches, plus the local
persistence format. The sample files are NOT in the repo yet; when they arrive
they MUST be placed in `test/fixtures/` and used to verify/adjust these
contracts (Constitution Principle VI). Field names are normalized: trim all
cell text before any comparison.

---

## 1. Input — Alpro HTML report (`.html`)

### Structure (expected, from spec §5)

- One HTML document, parsed with `package:html`.
- A data table whose **first header row** contains at least:
  - `Cow No.` (required; identifies the cow)
  - `MPC Address` (required for output `UnitNo`)
  - `Milk Yield` (required)
  - `Milk Dur.` (required, `HH:MM:SS`)
- Report-level `Date` and `Session` values appear as label/value pairs
  somewhere in the document (outside or above the table).

### Header matching rule

Normalize each header cell: `trim().toLowerCase()` and strip every character
except `a-z0-9` (`"Cow No."` → `cowno`). Then match required headers by
**prefix** (`_headerMatches`): the real report's `Cow No.` header carries a
trailing sort indicator and renders as `cowno1`, so an exact match would miss
it. Prefix anchors used: `cowno` (cow), `mpcaddress` (unit), `milyield`/
`milyeild` (yield), `milkdur` (duration). A header is matched if the normalized
cell **starts with** the anchor (trimmed to the same length to avoid false
prefix hits like `cownote`).

> **Verified (2026-08-10):** the prefix rule (especially `cowno1`) was
> confirmed against the real `test/fixtures/alpro_report.html` during T021.
> The variant spellings `milyield`/`milyeild` were also confirmed against the
> real header text. Missing required column → `AlproParseError` listing the
> missing column name.

### Date/Session search

Two strategies, tried in order on the real reports (2026-08-10):

1. **Pattern-based (primary):** the real report has no `Date:`/`Session:`
   labels. A date token matching `dd.dd.dd` (e.g. `26.08.08`) is read from the
   document text, and the active session number is parsed from the title
   `"Session N"` (→ `1`/`2`/`3`).
2. **Label-based (fallback):** search the document text for label matches
   `date` and `session` (case-insensitive); take the trimmed value that follows
   the label (a `<td>` sibling, a `: value` caption, or the nearest following
   single text node) — whichever the fixture shows.

If a value cannot be found, keep the column out of the output and surface a
warning instead of failing.

### Row parsing

For every data row in the located table: read the 4 required columns by their
header index, build an `AlproRecord` (see `data-model.md`). A row with an
unparsable cow number → whole report fails. Rows with **truly empty** `Milk
Yield` or `Milk Dur.` → skipped with warning (FR-014). Rows with a **non-empty**
non-numeric yield or non-time duration (`-`, dry-cow rows) are **kept** and
exported with `milkYield = 0.0` / `milkingTime = 0` — not skipped.

---

## 2. Input — Cow-list Excel (`.xlsx`)

### Structure

- One sheet with a **header row** (first non-empty row) and one number per
  data row. Conceptual layout:

```
Cow Number
----------
5
12
20
31
44
```

### Cow-number column detection (FR-004)

1. Read the first non-empty row as headers.
2. Normalize each header with the same rule as §1.
3. First header starting with `cownum` or equal to `cow` wins.
4. Otherwise: fall back to the **first column that contains at least one
   value that parses as an int**, and return a `usedFallback = true` flag so
   the UI can inform the user.
5. No column yields a valid int → `CowListError` ("no cow numbers found").
6. Data rows: skip fully blank rows; non-integer values in the chosen column
   are collected and reported as warnings; valid values are deduplicated into
   a `Set<int>` (FR-005).

---

## 3. Output — DairySense workbook (`.xlsx`)

### Structure

- One sheet. First row is exactly the following headers, in this order:

```
Date | Session | UnitNo | CowNumber | Milking Time | Milk yield | Conductivity | temperature
```

- One data row per `DairySenseRow` (cardinality 1:1, FR-009).
- No extra sheets, no styling requirements.
- `Conductivity` and `temperature` data cells: numeric `0`.
- `Milking Time`: integer seconds (e.g. `00:03:00` → `180`).
- `CowNumber`: integer. Other cells: plain string/double as the model says.

> When `test/fixtures/dairy_sense_template.xlsx` arrives, compare header row,
> sheet name, and cell format against it and adjust the writer constants (they
> live in one place: `dairy_sense_writer.dart`).

### Output file name (FR-015)

- Default: `DairySense_Import_<YYYY-MM-DD>_<H.mm am/pm>.xlsx` (conversion
  time, 12-hour am/pm; e.g. `DairySense_Import_2026-08-10_11.13 am.xlsx`).
- Offered via the native save dialog (editable by the user; the user picks the
  destination each time — the source report is never used as the output path).
- Write failure (existing/locked file) → `OutputWriteFailure` with a friendly
  message; the save dialog re-opens for the user to retry (FR-017).
- Cancelling the save dialog or the missing-cow dialog resets the cubit to
  idle: no file, no dialog, `CONVERT` re-enabled.

---

## 4. Persistence — `cow_list.json`

Stored at `getApplicationSupportDirectory()/cow_list.json`.

```json
{
  "cowNumbers": [5, 12, 20, 31, 44],
  "lastUpdated": "2026-08-09T10:15:00.000"
}
```

- Written **only after** a new list fully validates (FR-008: failed update must
  never destroy the previous file — the old file is only overwritten after
  validation passes).
- Load: missing file → no list; unreadable/parse-error JSON → no list with a
  user-facing explanation; never a crash.