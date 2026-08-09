# Implementation Plan: Alpro → DairySense Converter

**Branch**: `001-alpro-dairysense-converter` | **Date**: 2026-08-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-alpro-dairysense-converter/spec.md`

**Design goal of this plan**: MAXIMUM SIMPLICITY — this feature will be
implemented by a low-budget (cheaper) LLM agent. The plan therefore:
no architecture layers, no state-management library, no code generation, one
UI file, 5 packages, and every tricky function is pre-specified below with a
copy-paste reference. Anything not specified here is not required.

## Summary

A local-first Flutter **Windows desktop** app that converts an Alpro milking
HTML report into a DairySense XLSX import file, filtered by the current
DairySense cow-number list. The active cow list persists locally and is
reused automatically. Missing cows trigger a confirm dialog
(Cancel = no file). The conversion pipeline is pure Dart code, fully testable
without the UI.

## Technical Context

| Area | Decision |
|---|---|
| **Language/Version** | Dart, Flutter SDK `^3.x` (already `sdk: ^3.12.2` in pubspec) |
| **Primary Dependencies** | `html` (parse report), `excel` (read cow list + write workbook), `file_picker` (file/folder/save dialogs), `path_provider` (app data dir), `path` (join paths). Add with: `flutter pub add html excel file_picker path_provider path` |
| **Storage** | Single JSON file `cow_list.json` in `getApplicationSupportDirectory()` (no database) |
| **Testing** | `flutter_test` only. Unit tests for pure pipeline functions; one integration test against real fixture files in `test/fixtures/` once supplied |
| **Target Platform** | Windows desktop (only platform MVP requires) |
| **Project Type** | Desktop GUI application; core conversion logic is a pure Dart library usable headless |
| **Performance Goals** | Parse/filter/transform + write ~5,000 records; UI never frozen (one `Isolate.run` call) |
| **Constraints** | Local-only, offline, deterministic pipeline, no mapping of cow lists, no fake data, user picks output folder every time |
| **Scale/Scope** | One active cow list, one screen, 8 output columns, ~10 source files |
| **Open items** | The three supplied sample files are **not yet in the repo**. The contracts (`contracts/file-formats.md`) are written from the spec; when the files arrive in `test/fixtures/`, the implementer MUST verify/adjust the header maps in `alpro_parser.dart` / `dairy_sense_writer.dart` and make the integration test pass on them. This is a verification step, not a blocker for the code structure. Those provisional header variants are never authoritative (Constitution VI — see contracts §1). Performance (SC-006) and input-non-mutation (FR-019) and no-fixed-limit (FR-020) are verified by tests T026/T027, not just by design. |

All items resolved — **no NEEDS CLARIFICATION** remains.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|---|---|---|
| I. Local-first, no backend | No network/login/cloud; persistence survives restarts (JSON file) | ✅ PASS by design |
| II. Cow list is a filter | Set<int> filter; never saved without validation; no cow list → no export (FR-021/NoCowListError) | ✅ PASS by design |
| III. Deterministic pipeline, testable without Flutter | `converter.dart` + `alpro_parser.dart` + `dairy_sense_writer.dart` are pure Dart functions with no `dart:ui` import; UI only orchestrates | ✅ PASS by design |
| IV. Fail-safe data integrity | Old list overwritten only after new one validates; missing cows force dialog; workbook built in memory, saved only after all validation; folder picked every time; typed user-friendly errors | ✅ PASS by design |
| V. Test-first with regression fixtures | Tasks define failing tests first; integration test driven by the real fixture files; fixtures directory reserved | ✅ PASS (fixtures pending arrival) |
| VI. Structure-based parsing, never invented formats | Parsing by table+headers via `package:html`; header maps derived from spec and MUST be adjusted to the real files; dependencies minimal & maintained | ✅ PASS |

**Gate result: PASS.** No violations. The only caveat (fixtures absent) is
documented as a verification step, not a design deviation.

## Project Structure

### Documentation (this feature)

```text
specs/001-alpro-dairysense-converter/
├── plan.md              # This file
├── research.md          # Phase 0: resolved decisions
├── data-model.md        # Phase 1: entities & rules
├── quickstart.md        # Phase 1: run/validate guide
├── contracts/
│   └── file-formats.md  # Phase 1: 3 external formats + persistence format
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT part of /speckit.plan)
```

### Source Code (repository root)

```text
lib/
├── main.dart              # entry + ENTIRE UI (1 StatefulWidget screen + dialogs)
├── models.dart            # data classes + typed errors (see data-model.md)
├── alpro_parser.dart      # parseAlproReport(String html) -> AlproReport
├── cow_list_loader.dart   # loadCowListFromXlsx(String path) -> CowListLoadResult
├── cow_list_store.dart    # saveCowList/getCowListFile -> CowList?
├── converter.dart         # all pure pipeline functions (see signatures below)
└── dairy_sense_writer.dart# writeDairySenseXlsx(List<DairySenseRow>, String path)

test/
├── alpro_parser_test.dart
├── converter_test.dart
├── cow_list_test.dart     # loader + store
├── integration_test.dart  # end-to-end with test/fixtures/* (when supplied)
└── fixtures/              # alpro_report.html, current_cow_list.xlsx, dairy_sense_template.xlsx
```

**Structure Decision**: Flat single-project layout. The constitution's
Presentation/Application/Domain/Infrastructure separation is preserved as
*file separation* (UI ↔ pure code) instead of folders-with-classes, because
the pipeline functions themselves ARE the application layer. 7 lib files is
the whole app. Do NOT create folders like `features/`, `domain/`, or
`data/` — flat files only.

## Implementation order (each step ends green)

> Converts the spec's 6 phases into one linear, cheap-model-friendly order.
> Every step: write the failing test(s) first, then the code (Constitution V).

1. **Foundation** — `flutter pub add html excel file_picker path_provider path`;
   delete `test/widget_test.dart` (references the old counter app); verify
   `flutter analyze` + `flutter test` are clean. (`models.dart` lands here too.)
2. **Converter core (pure)** — `converter.dart` functions below, tested in
   `converter_test.dart`.
3. **Alpro parser** — `alpro_parser.dart`, tested in `alpro_parser_test.dart`.
4. **Cow list** — `cow_list_loader.dart` + `cow_list_store.dart`, tested in
   `cow_list_test.dart` (round-trip save/load with a temp dir).
5. **Workbook writer** — `dairy_sense_writer.dart`, tested via
   `converter_test.dart` (write to temp dir, read back with `excel`, assert
   header order and values).
6. **UI** — `main.dart`: one screen, three dialogs, `Isolate.run` orchestration.
7. **Integration + polish** — `integration_test.dart` on fixture files; friendly
   error paths; `flutter build windows`.

## Pre-specified core functions (`converter.dart`)

Exact signatures so the implementer never guesses. All in one file, all pure.

```dart
/// FR-005: trim; int, else double with .0, else null.
int? normalizeCowNumber(String raw);

/// FR-014: "HH:MM:SS" -> seconds; anything else -> null. Example 00:03:00 -> 180.
int? durationToSeconds(String? raw);
// Reference: split on ':', parse 3 ints, return h*3600 + m*60 + s; null on any failure.

/// FR-009: keep records whose cowNumber is in list, original order.
List<AlproRecord> filterRecords(List<AlproRecord> records, Set<int> cowNumbers);

/// FR-010: selected cows absent from the report, sorted ascending.
List<int> detectMissingCows({required Set<int> selected, required Set<int> inReport});

/// FR-012/013/014: build the output rows (Conductivity/temperature = 0).
List<DairySenseRow> buildDairySenseRows(AlproReport report, List<AlproRecord> matched);

/// The ENTIRE pipeline, synchronous and side-effect-free except writing the file:
/// parse -> filter -> missing cows -> transform -> build rows -> validate non-empty ->
/// write workbook -> return result. Throws typed errors (data-model.md §6).
/// Throws NoCowListError when `cowNumbers` is empty (an empty set means "no list",
/// distinct from the FR-021 zero-match case where a list exists but nothing matches).
ConversionResult runConversion({
  required String alproHtmlPath,
  required Set<int> cowNumbers,
  required String outputXlsxPath,
});
```

Pre-specified tricky helpers, copy as-is:

```dart
// Header normalization (contracts/file-formats.md §1)
String normalizeHeader(String cell) =>
    cell.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
// "Cow No." -> "cowno", "MPC Address" -> "mpcaddress", "Milk Dur." -> "milkdur"

// Cow number normalization (FR-005)
int? normalizeCowNumber(String raw) {
  final t = raw.trim();
  final i = int.tryParse(t);
  if (i != null) return i;
  final d = double.tryParse(t);
  if (d != null && d == d.roundToDouble()) return d.toInt();
  return null; // "5.0" -> 5; "07" -> 7; "abc" -> null
}
```

## UI contract (`main.dart`)

- `MainScreen` = one `StatefulWidget`; state: `selectedHtmlPath`,
  `CowList? activeCowList`, `bool busy`, `ConversionResult? lastResult`.
- `setState` is the only state mechanism. Async work is
  `await Isolate.run(() => runConversion(...))` — no manual isolate plumbing.
- Components (all in the same file):
  1. "Select HTML file" button → `FilePicker.platform.pickFiles(type:
     FileType.custom, allowedExtensions: ['html'])`.
  2. Cow list card: count, "Last updated: <ts>", source (saved/imported),
     "Update Cow List" button → pick `.xlsx` → load → then
     `saveCowList(...)`.
  3. `[CONVERT]` → pipeline → on `missing.isNotEmpty` show the missing-cow
     dialog (`[Cancel] [Continue]`); Continue → save dialog
     (`FilePicker.platform.saveFile(fileName: DairySense_Import_<ts>.xlsx,
     type: FileType.custom, allowedExtensions: ['xlsx'])`) → save → summary
     dialog (report records / selected / found / missing / warnings / path).
  4. Every pipeline error → `AlertDialog` with the typed message. Never a
     stack trace (FR-017).

## Complexity Tracking

> No gate violations; this table documents the deliberate simplifications
> made because implementation uses a cheaper model.

| Simplification | Why it is enough | Full alternative rejected because |
|---|---|---|
| No state-management library, plain `setState` | One screen, 4 states, no cross-widget sharing | Riverpod/Bloc adds concepts a cheap model can misuse |
| No repository/use-case classes; free functions in `converter.dart` | The pipeline IS the application logic; functions are trivially testable | Class layers obscure the data flow |
| Whole UI in `main.dart` (~350 lines) | One screen + 4 small dialogs | Splitting UI files adds cross-file wiring errors |
| JSON file instead of SQLite | One list, ~10 KB | DB setup/ORMs are overkill and native-plugin risky on Windows |
| Single `Isolate.run` instead of streamed progress | Requirement is only "UI stays responsive" | Progress streams add protocol complexity for no MVP value |
| `excel` package does both read and write | Both skills are needed and trivial in it | Two packages = two APIs to learn for the implementer |
| Raw report `Date`/`Session` passthrough (strings) | Spec forbids clock/guess values; formatting verified against template later | Format conversion now would be invented format handling (Principle VI) |

## Deliverables of this plan

- `research.md` — decisions + rationale for every choice above.
- `data-model.md` — entities, validation, error types, state transitions.
- `contracts/file-formats.md` — the three file formats + persistence JSON.
- `quickstart.md` — run/validate guide + integration-test assertions.
- Next command: `/speckit.tasks` generates `tasks.md` per task from the
  implementation order above.