# Quickstart: Alpro → DairySense Converter

**Date**: 2026-08-09
**Purpose**: Proves the feature works end-to-end. Setup → run → verify.
Details for each format live in
[`contracts/file-formats.md`](contracts/file-formats.md); the data rules live
in [`data-model.md`](data-model.md).

---

## 1. Prerequisites

- Flutter SDK `^3.x` with **Windows desktop** enabled
  (`flutter config --enable-windows-desktop`).
- Windows build toolchain (Visual Studio 2022 with "Desktop development with
  C++" workload) — required by `flutter build windows` / `flutter run -d windows`.
- The three supplied real files, once available, placed here:

```text
test/fixtures/
├── alpro_report.html           # the ~147-record Alpro report
├── current_cow_list.xlsx       # the DairySense cow-number list
└── dairy_sense_template.xlsx   # the DairySense import template (reference)
```

(Unit tests below work without them; the integration test needs them.)

## 2. Setup

```bash
flutter pub get
flutter analyze        # must report no errors
flutter test           # unit tests must pass (test-first, Constitution V)
```

## 3. Run

```bash
flutter run -d windows
```

## 4. Manual validation scenario (the 5 acceptance cases)

In the running app:

| # | Action | Expected |
|---|--------|----------|
| A | Select Alpro HTML, then **Update Cow List** with `current_cow_list.xlsx` | list shows count + "Last updated" timestamp; filtering uses it |
| B | Restart app (no new list import), select HTML, Convert | saved list is used automatically (status shows it was loaded from saved data) |
| C | Import a valid list, then import a broken file (e.g. text file renamed `.xlsx`) | update rejected with friendly message; previous list still shown |
| D | Convert with a list containing a cow not in the report | dialog lists the missing cow; **Cancel** → no file anywhere; **Continue** → file without that cow |
| E | Complete a successful conversion | save dialog always appears; file lands only in the chosen folder |

Edge checks: converting with no list shows "import a current cow list first"
and creates nothing; a report with zero matching cows produces no file and an
explanation.

## 5. Automated validation (test-first order)

```bash
flutter test test/converter_test.dart   # normalization, filtering, missing detection, duration, mapping (Conductivity/temperature = 0)
flutter test test/alpro_parser_test.dart
flutter test test/cow_list_test.dart    # loader + store (persistence round-trip)
flutter test test/integration_test.dart # real fixtures: count, cows, yields, units, seconds, zeros, column order
flutter test                            # all
```

Integration test asserts, on the fixture files (see spec §16):

- output row count equals the number of matching Alpro records;
- exported `CowNumber` set equals the intersection of report × list;
- `Milking Time` equals total seconds; `Conductivity` and `temperature` are `0`;
- header order is exactly
  `Date, Session, UnitNo, CowNumber, Milking Time, Milk yield, Conductivity, temperature`.

## 6. Definition of Done check

```bash
flutter build windows   # succeeds
flutter analyze         # clean
flutter test            # all green, including the fixture-based integration test
```

Then walk through the ✔ rows of the manual table once more against the built
EXE (`build/windows/x64/runner/Release/alfa_milk.exe`).