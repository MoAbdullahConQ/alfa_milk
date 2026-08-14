# Implementation Plan: Alpro → DairySense Converter

**Branch**: `001-alpro-dairysense-converter` | **Date**: 2026-08-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-alpro-dairysense-converter/spec.md`

**Design goal of this plan**: MAXIMUM SIMPLICITY **with clean architecture** —
this feature will be implemented by a low-budget (cheaper) LLM agent. The plan
therefore uses a lightweight clean-architecture split (`core/` + `features/`
+ a single UI file), no state-management library, no code generation, one UI
file, 5 packages, and every tricky function is pre-specified below with a
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
| **Open items** | **None — all resolved.** The three supplied sample files are now in `test/fixtures/` (`alpro_report.html`, `current_cow_list.xlsx`, `dairy_sense_template.xlsx`); the header maps in `alpro_parser.dart` / `dairy_sense_writer.dart` were verified against them and the integration test passes. Performance (SC-006), input-non-mutation (FR-019), and no-fixed-limit (FR-020) are verified by tests T026/T027. |

**Real-file verification (2026-08-10 → 2026-08-14):** the user's real Alpro HTML
reports (`Session1 8-8.htm.html`, `Session2 7-8.htm.html`, `session 3 7-8.htm.html`)
were provided and the parser was adjusted + verified against them: required
headers are matched by **prefix** to tolerate a trailing sort-indicator digit
(the `Cow No.` header renders as `cowno1`); only a truly empty yield/dur cell
is skipped, while non-numeric yield and non-time duration (`-`) are kept and
exported as `0` (dry-cow rows); real **Date** (`26.08.08`) and **Session**
(`1`/`2`/`3`) are extracted from the report text (label-based extraction kept
as fallback). Results: Session1=147, Session2=127, Session3=140 records
converted end-to-end. The real cow-list (`current_cow_list.xlsx`, 41 cows) and
template (`dairy_sense_template.xlsx`) files are shipped as fixtures; the
integration test runs green on them, and generated files import into real
DairySense (verified 2026-08-13).

**Released 2026-08-14 as v1.0.0** (tag `v1.0.0`): all 27 tasks in `tasks.md`
complete; `flutter analyze` clean; `flutter test` green (52 unit +
integration tests, incl. T026/T027); `flutter build windows` succeeds; manual
acceptance (quickstart §4 cases A–G) passed.

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
├── main.dart                       # entry + shared MainScreen shell (composition root)
├── core/                           # shared, framework-independent, no feature logic
│   ├── errors/
│   │   ├── failures.dart           # Failure base + typed failures (dartz Either)
│   │   └── custom_exceptions.dart  # thrown typed errors (see data-model.md §6)
│   ├── helper_functions/           # error_dialog, file_picker_helper, show_conversion_summary
│   ├── utils/
│   │   └── app_utils.dart          # normalizeHeader, normalizeCowNumber, durationToSeconds
│   ├── models/  widgets/  services/  # shared (Uni-pattern placeholders)
└── features/                       # feature modules, each self-contained
    ├── home/                       # Alpro → DairySense pipeline (Uni pattern)
    │   ├── data/
    │   │   ├── data_sources/
    │   │   │   ├── alpro_parser.dart      # parseAlproReport + AlproParser class
    │   │   │   └── dairy_sense_writer.dart # writeDairySenseXlsx + DairySenseWriter class
    │   │   └── repos/
    │   │       └── conversion_repo_impl.dart  # implements ConversionRepo, Either<Failure,T>
    │   ├── domain/
    │   │   ├── entities/           # alpro_record, alpro_report, cow_list, dairy_sense_row, conversion_result
    │   │   ├── repos/
    │   │   │   └── conversion_repo.dart  # abstract boundary (Either<Failure,T>)
    │   │   └── use_cases/          # filter_records, detect_missing_cows, build_dairy_sense_rows, convert_report
    │   └── presentation/
    │       ├── manager/
    │       │   └── conversion_cubit/  # conversion_cubit.dart + part conversion_state.dart
    │       └── views/              # main_screen.dart + widgets/ (cow_list_card, report_convert_view)
    └── cow_list/                   # cow list management (US2)
        ├── data/
        │   ├── cow_list_loader.dart    # loadCowListFromXlsx(String path)
        │   └── cow_list_store.dart     # saveCowList/getCowListFile -> CowList?
        ├── domain/                 #   entities + use_cases
        └── presentation/
            └── cow_list_card.dart

test/
├── alpro_parser_test.dart
├── converter_test.dart
├── cow_list_test.dart     # loader + store
├── integration_test.dart  # end-to-end with test/fixtures/* (when supplied)
└── fixtures/              # alpro_report.html, current_cow_list.xlsx, dairy_sense_template.xlsx
```

**Structure Decision**: **Clean architecture** mirroring the `Uni` repo
pattern (feature-first, bloc + dartz). Dependencies point inward:
`main.dart` → `features/*/presentation` → `features/*/domain` →
`features/*/data` → `core/`. `core/` has no feature knowledge; each feature owns
its data (external formats), domain (pure business rules + use cases + repo
abstraction), and presentation (widgets + cubit) layers.

- `core/errors/failures.dart` — `Failure` base + typed failures; the data layer
  maps thrown `custom_exceptions.dart` to `dartz.Either<Failure, T>`.
- `core/helper_functions/`, `core/utils/`, `core/models/`, `core/widgets/`,
  `core/services/` — shared, framework-independent helpers.
- `features/*/domain/` — `entities/`, `repos/` (abstract boundary), `use_cases/`
  (thin, wrap the repo, stay pure, no `dart:ui`).
- `features/*/data/` — `data_sources/` (parse/write IO as classes),
  `repos/*_repo_impl.dart` (implements the abstract repo, returns `Either`).
- `features/*/presentation/` — `manager/*_cubit/` (flutter_bloc Cubit + part
  state), `views/` + `views/widgets/`.

`main.dart` remains the only app shell and composition root (constructs the
repo → use case → cubit chain).

## Implementation order (each step ends green)

> Converts the spec's 6 phases into one linear, cheap-model-friendly order.
> Every step: write the failing test(s) first, then the code (Constitution V).

1. **Foundation** — `flutter pub add html excel file_picker path_provider path
   flutter_bloc dartz`; delete `test/widget_test.dart` (references the old
   counter app); verify `flutter analyze` + `flutter test` are clean.
   (`core/errors/failures.dart`, `core/errors/custom_exceptions.dart`, and
   `core/utils/app_utils.dart` land here too.)
2. **Domain (pure)** — `features/home/domain/entities/*`,
   `features/home/domain/repos/conversion_repo.dart` (abstract),
   `features/home/domain/use_cases/{filter_records,detect_missing_cows,build_dairy_sense_rows,convert_report}_use_case.dart`,
   tested in `converter_test.dart`.
3. **Alpro parser** — `features/home/data/data_sources/alpro_parser.dart`
   (`parseAlproReport` + `AlproParser` class), tested in `alpro_parser_test.dart`.
4. **Cow list** — `features/cow_list/data/cow_list_loader.dart` +
   `cow_list_store.dart`, tested in `cow_list_test.dart` (round-trip save/load
   with a temp dir).
5. **Workbook writer** — `features/home/data/data_sources/dairy_sense_writer.dart`
   (`writeDairySenseXlsx` + `DairySenseWriter` class), tested via
   `converter_test.dart` (write to temp dir, read back with `excel`, assert
   header order and values).
6. **Data repo impl** — `features/home/data/repos/conversion_repo_impl.dart`
   implements `ConversionRepo`, runs the pipeline in `Isolate.run`, maps thrown
   exceptions → `Either<Failure, ConversionResult>`.
7. **UI** — `main.dart` (shell) + `features/home/presentation` widgets and
   `conversion_cubit`, one screen, three dialogs, `Isolate.run` orchestration.
8. **Integration + polish** — `integration_test.dart` on fixture files; friendly
   error paths; `flutter build windows`.

## Pre-specified core functions (`features/home/domain/use_cases/`)

Exact signatures so the implementer never guesses. Now thin use-case classes
wrapping the abstract `ConversionRepo` (Uni pattern). Pure logic stays in the
use cases; IO lives in the data layer.

```dart
// FR-005: trim; int, else double with .0, else null. (core/utils/app_utils.dart)
int? normalizeCowNumber(String raw);

// FR-014: "HH:MM:SS" -> seconds; anything else -> null. (core/utils/app_utils.dart)
int? durationToSeconds(String? raw);

// FR-009: keep records whose cowNumber is in list, original order.
class FilterRecordsUseCase {
  List<AlproRecord> call(List<AlproRecord> records, Set<int> cowNumbers);
}

// FR-010: selected cows absent from the report, sorted ascending.
class DetectMissingCowsUseCase {
  List<int> call({required Set<int> selected, required Set<int> inReport});
}

// FR-012/013/014: build the output rows (Conductivity/temperature = 0).
class BuildDairySenseRowsUseCase {
  List<DairySenseRow> call(AlproReport report, List<AlproRecord> matched);
}

// Orchestrator: guards no-cow-list, delegates to the repo (Either).
class ConvertReportUseCase {
  Future<Either<Failure, ConversionResult>> call({
    required String alproHtmlPath,
    required CowList? cowList,
    required String outputXlsxPath,
  });
}

// Abstract boundary implemented by features/home/data/repos/conversion_repo_impl.dart.
abstract class ConversionRepo {
  Future<Either<Failure, AlproReport>> parseAlproReport(String htmlPath);
  Future<Either<Failure, ConversionResult>> runConversion({
    required String alproHtmlPath,
    required CowList cowList,
    required String outputXlsxPath,
  });
}
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

## UI contract (`main.dart` + `features/home/presentation`)

- `MainScreen` = one `StatefulWidget` in `lib/features/home/presentation/views/main_screen.dart`; UI-local state: `selectedHtmlPath`, `CowList? activeCowList`. It builds the repo → use case → cubit chain and provides it via `BlocProvider.value`.
- State management is **flutter_bloc**: `ConversionCubit` in
  `presentation/manager/conversion_cubit/` with states `ConversionInitial /
  ConversionLoading / ConversionSuccess / ConversionFailure`. The UI reads
  busy/result/failure via `BlocBuilder` / `BlocListener`. Pipeline work runs in
  `await Isolate.run(...)` inside the repo impl — no manual isolate plumbing.
- Components:
   1. "Select HTML file" button → `FilePicker.pickFiles(type:
      FileType.custom, allowedExtensions: ['html'])` (file_picker v11 static API).
  2. Cow list card: count, "Last updated: <ts>", source (saved/imported),
     "Update Cow List" button → pick `.xlsx` → load → then
     `saveCowList(...)`.
   3. `[CONVERT]` → cubit → on `missing.isNotEmpty` show the missing-cow
      dialog (`[Cancel] [Continue]`); Continue → **native save dialog**
      (`FilePicker.saveFile(fileName: DairySense_Import_<YYYY-MM-DD>_<H.mm
      am/pm>.xlsx, type: FileType.custom, allowedExtensions: ['xlsx'])` — the
      user picks the destination every time, and the source report is never used
      as the output path) → save → summary dialog (report records / selected /
      found / missing / warnings / path).
   4. Every pipeline error → `AlertDialog` with the typed `Failure.message`.
      Never a stack trace (FR-017).
   5. **Cancel-safe (T019)**: cancelling the save dialog or the missing-cow
      dialog calls `ConversionCubit.reset()` (→ `ConversionInitial`), which
      immediately re-enables `CONVERT`, creates no file and shows no dialog, so
      the user can convert again without restarting. An output-write failure
      (locked / existing file) shows a friendly `OutputWriteFailure` message and
      re-opens the save dialog to retry (FR-017).
   6. **Selectable text**: all user-visible dialog and summary text uses
      `SelectableText` (copyable via mouse selection / Ctrl+C) — conversion
      summary, error dialogs, missing-cow dialog, and the cow-list validation
      snackbar.

## Complexity Tracking

> No gate violations; this table documents the deliberate simplifications
> made because implementation uses a cheaper model.

| Simplification | Why it is enough | Full alternative rejected because |
|---|---|---|
| flutter_bloc Cubit for state | Matches the `Uni` repo pattern the project mirrors; one small cubit per feature is idiomatic and testable | Plain `setState` (plan v1) was rejected to keep architecture consistent with `Uni` |
| Clean-arch with repo + use-case classes (`core/` + `features/` data/domain/presentation) | Clear, testable separation; core is shared & pure; matches `Uni` | Full MVVM/DI registries add wiring a cheap model can misuse |
| `dartz.Either<Failure, T>` at the data/domain boundary | Idiomatic failure modeling matching `Uni`; UI reads `.message` | Raw thrown exceptions leaking to widgets |
| Repo impl runs the whole pipeline in a single `Isolate.run` | Requirement is only "UI stays responsive" | Streamed progress adds protocol complexity for no MVP value |
| Whole UI split across `main.dart` shell + feature `presentation/` (~350 lines total) | One screen + 4 small dialogs, feature widgets colocated with their logic | A single flat UI file mixes feature concerns |
| JSON file instead of SQLite | One list, ~10 KB | DB setup/ORMs are overkill and native-plugin risky on Windows |
| `excel` package does both read and write | Both skills are needed and trivial in it | Two packages = two APIs to learn for the implementer |
| Raw report `Date`/`Session` passthrough (strings) | Spec forbids clock/guess values; formatting verified against template later | Format conversion now would be invented format handling (Principle VI) |

## Deliverables of this plan

- `research.md` — decisions + rationale for every choice above.
- `data-model.md` — entities, validation, error types, state transitions.
- `contracts/file-formats.md` — the three file formats + persistence JSON.
- `quickstart.md` — run/validate guide + integration-test assertions.
- Next command: `/speckit.tasks` generates `tasks.md` per task from the
  implementation order above.