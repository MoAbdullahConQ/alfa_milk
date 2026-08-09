# Data Model: Alpro → DairySense Converter

**Date**: 2026-08-09
**Source**: `spec.md` (Key Entities) + `docs/alpro_dairysense_plan.md`

All models are plain Dart classes in `lib/models.dart`. No code generation,
no JSON annotations, no equality package — hand-written `==`/`hashCode` only
where tests need them. Keep every class small and obvious.

---

## 1. AlproRecord

One milking event row parsed from the Alpro HTML table.

| Field      | Type   | Source column   | Nullable | Notes                                    |
|------------|--------|-----------------|----------|------------------------------------------|
| cowNumber  | int    | `Cow No.`       | no       | normalized (see FR-005)                  |
| unitNo     | String | `MPC Address`   | yes      | empty string if missing                  |
| milkYield  | double | `Milk Yield`    | yes      | null if missing/invalid                  |
| milkDur    | String | `Milk Dur.`     | yes      | `HH:MM:SS`; null if missing/invalid      |

### Validation rules

- Row is **skipped with a warning** (FR-014) when `milkYield` is null OR
  `milkDur` is null or not `HH:MM:SS`. `unitNo` missing does NOT skip.
- A row whose `cowNumber` cannot be parsed is invalid for the whole report:
  **report parse fails** with a clear message (a real Alpro report row must
  have a cow number). Never silently drop an unparsable cow row.

## 2. AlproReport

Result of parsing the HTML document.

| Field     | Type                | Notes                                |
|-----------|---------------------|--------------------------------------|
| date      | String              | extracted from report, never clock   |
| session   | String              | extracted from report, never hardcoded |
| records   | List\<AlproRecord\> | all parsed rows, original order      |
| warnings  | List\<String\>      | FR-014 skips reported here           |

`date` and `session` keep their raw (trimmed) textual values; formatting for
the output workbook is done in the writer in one obvious place.

## 3. CowList

The persisted current list.

| Field       | Type          | Notes                                        |
|-------------|---------------|----------------------------------------------|
| cowNumbers  | Set\<int\>    | deduplicated, FR-005                         |
| lastUpdated | DateTime      | when the list was successfully imported      |

### Rules

- A cow list is **valid** if it extracted at least one valid cow number.
- Import errors (unreadable file, no valid numbers) reject the list and keep
  the previous one (FR-008).
- The saved JSON is `{"cowNumbers": [...], "lastUpdated": "<ISO-8601>"}`.
  Corrupt/missing JSON on load → treat as "no list" (never crash, explain).

## 4. DairySenseRow

One output row for the workbook (FR-012 columns, exact order).

| Field (column) | Type     | Value rule                              |
|----------------|----------|-----------------------------------------|
| Date           | String   | from `AlproReport.date`                 |
| Session        | String   | from `AlproReport.session`              |
| UnitNo         | String   | from `AlproRecord.unitNo`               |
| CowNumber      | int      | from `AlproRecord.cowNumber`            |
| Milking Time   | int      | `milkDur` → total seconds (FR-014)      |
| Milk yield     | double   | from `AlproRecord.milkYield`            |
| Conductivity   | int      | always `0`                              |
| temperature    | int      | always `0`                              |

Cardinality: **1 Alpro record → 1 DairySense row** (FR-009).

## 5. ConversionResult

Returned by the pipeline after saving.

| Field       | Type            | Notes                                   |
|-------------|-----------------|-----------------------------------------|
| reportCount | int             | records parsed from the report          |
| selected    | int             | cow list size used                      |
| found       | int             | matched records exported                |
| missing     | List\<int\>     | selected cows absent from the report    |
| warnings    | List\<String\>  | FR-014 skips                            |
| outputPath  | String?         | null when nothing was saved             |

## 6. Pipeline errors (typed, user-friendly)

Thrown by the pipeline so the UI can show messages (never stack traces,
Constitution Principle IV):

| Error type           | Message pattern                          |
|----------------------|------------------------------------------|
| `AlproParseError`    | "The selected file is not a valid Alpro report: <detail>" |
| `CowListError`       | "The cow list could not be read: <detail>" |
| `OutputWriteError`   | "The file could not be saved: <detail>"  |
| `NoCowListError`     | "Import a current cow list before converting." |

## 7. State transitions

```
[No list] --import valid xlsx--> [CowList saved+active]
[No list] --import invalid xlsx--> [No list]            (old list preserved if any)
[CowList active] --import valid xlsx--> [new CowList saved (replaces old)]
[CowList active] --import invalid xlsx--> [CowList active unchanged]
[CowList active] + Alpro report --convert--> [ConversionResult] (file saved)
[CowList active] + Alpro report, 0 matches --> error, no file (FR-021)
```

There is no other persistent state. The app process state is: selected HTML
path, active `CowList` (in memory), and the last `ConversionResult`.