# Tasks: Alpro → DairySense Converter

**Input**: Design documents from `/specs/001-alpro-dairysense-converter/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/file-formats.md

**Tests**: Tests ARE required. The spec mandates "User Scenarios & Testing (mandatory)" and the constitution (Principle V, NON-NEGOTIABLE) enforces test-first with regression fixtures. Every test task MUST be written first (RED), then implementation turns it green.

**Cheap-model guardrails** (from plan.md): flat files only — NO folders like `features/`, `domain/`, `data/`. No state-management library (plain `setState`). No code generation. No extra packages beyond the 5 listed. Copy the pre-specified function signatures and helpers from plan.md verbatim — do not invent abstractions. The whole UI lives in `lib/main.dart`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Flutter project at repository root: `lib/` (source), `test/` (tests), `test/fixtures/` (real sample files)
- All lib files are flat at `lib/` root: main.dart, models.dart, alpro_parser.dart, cow_list_loader.dart, cow_list_store.dart, converter.dart, dairy_sense_writer.dart

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and dependencies

- [ ] T001 Add the 5 dependencies with `flutter pub add html excel file_picker path_provider path` (updates pubspec.yaml and pubspec.lock)
- [ ] T002 [P] Delete `test/widget_test.dart` (stale counter-app test that would fail after main.dart is rewritten)
- [ ] T003 Verify baseline is clean: run `flutter analyze` and `flutter test` and confirm no errors

**Checkpoint**: Dependencies installed, stale test removed, baseline green.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared data model + fixtures directory that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Create `lib/models.dart` with ALL entities and typed errors exactly per `data-model.md`: `AlproRecord`, `AlproReport`, `CowList`, `DairySenseRow`, `ConversionResult`, plus typed errors `AlproParseError`, `CowListError`, `OutputWriteError`, `NoCowListError` with the exact message patterns from data-model.md §6. Plain Dart classes, hand-written `==`/`hashCode` only where tests need them, no JSON annotations
- [ ] T005 [P] Create `test/fixtures/` directory with a `.gitkeep` placeholder and a short `README.md` listing the 3 expected real files: `alpro_report.html`, `current_cow_list.xlsx`, `dairy_sense_template.xlsx` (they arrive later; see Phase 7 T021)

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Convert a milking report into a DairySense import file (Priority: P1) 🎯 MVP

**Goal**: User selects an Alpro HTML report and gets a DairySense-ready XLSX containing only the cows on the current cow list, with correct columns and values.

**Independent Test**: Run `flutter test test/converter_test.dart test/alpro_parser_test.dart` — all pure-pipeline tests pass without any UI; the parser and conversion core are proven correct.

### Tests for User Story 1 (write FIRST, must FAIL before implementation) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation** (Constitution V)

- [ ] T006 [P] [US1] Write unit tests in `test/converter_test.dart` covering: `normalizeCowNumber` (`"07"`→7, `" 5.0 "`→5, `"abc"`→null), `durationToSeconds` (`"00:03:00"`→180, invalid→null), `filterRecords` (only list cows, original order preserved), `detectMissingCows` (sorted ascending), `buildDairySenseRows` (Conductivity/temperature = 0, Milking Time in seconds), and a workbook round-trip: `writeDairySenseXlsx` to a temp dir, read back with the `excel` package, assert the 8 headers in exact order `Date, Session, UnitNo, CowNumber, Milking Time, Milk yield, Conductivity, temperature` and row values
- [ ] T007 [P] [US1] Write unit tests in `test/alpro_parser_test.dart` covering: `normalizeHeader` (`"Cow No."`→`cowno`, `"MPC Address"`→`mpcaddress`, `"Milk Dur."`→`milkdur`), a small inline HTML sample with the header row + 2 data rows (correct records parsed, Date/Session extracted), missing required column → throws `AlproParseError` naming the column, row with unparsable cow number → whole parse fails, row with missing `Milk Yield`/`Milk Dur.` → skipped with a warning

### Implementation for User Story 1

- [ ] T008 [P] [US1] Implement `lib/alpro_parser.dart`: `parseAlproReport(String html) → AlproReport` per `contracts/file-formats.md` §1 using `package:html` (`querySelectorAll('table')`, header-index based column mapping with the `normalizeHeader` helper copied from plan.md). Locate the table whose header row contains `cowno`; extract `Date`/`Session` by searching document text for labels `date`/`session` (missing label → warning, not failure). Unparsable cow number → `AlproParseError`; missing yield/dur → skip with warning (FR-014)
- [ ] T010 [P] [US1] Implement `lib/dairy_sense_writer.dart`: `writeDairySenseXlsx(List<DairySenseRow>, String path)` per `contracts/file-formats.md` §3 — one sheet, first row the 8 headers in exact order, one data row per record (FR-009), `Conductivity`/`temperature` written as numeric `0`, `Milking Time` integer seconds, `CowNumber` integer. Header/sheet-name constants live in ONE place at the top of this file (for later fixture-based adjustment)
- [ ] T009 [US1] Implement `lib/converter.dart` with the EXACT pre-specified signatures from plan.md (copy the helper bodies verbatim): `normalizeCowNumber`, `durationToSeconds`, `filterRecords`, `detectMissingCows`, `buildDairySenseRows`, and `runConversion` (parse → filter → missing → transform → build rows → validate non-empty → write workbook → return `ConversionResult`). Throws typed errors; depends on T004 (models), T008 (parser), T010 (writer)
- [ ] T011 [US1] Make `test/converter_test.dart` and `test/alpro_parser_test.dart` pass (RED → GREEN). `flutter analyze` must be clean
- [ ] T012 [US1] Build the app shell in `lib/main.dart`: `MainScreen` `StatefulWidget` with state `selectedHtmlPath`, `CowList? activeCowList`, `bool busy`, `ConversionResult? lastResult`; "Select HTML file" button (`FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['html'])`); a placeholder cow-list card (count + "Last updated" + source — populated in US2); `[CONVERT]` button that runs the pipeline via `await Isolate.run(() => runConversion(...))` (never manual isolate plumbing); summary dialog after conversion showing report records / selected / found / missing / warnings / output path. `setState` is the only state mechanism

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently (pure pipeline green + UI shell runs).

---

## Phase 4: User Story 2 - Trust the current cow list (Priority: P1)

**Goal**: User imports a cow-list XLSX; it validates, persists locally, auto-reloads after restart; a failed import never removes the previous valid list.

**Independent Test**: Run `flutter test test/cow_list_test.dart` (loader + store round-trip in a temp dir). In the app: import a valid list, restart, confirm the same list is still active (quickstart.md §4 cases B and C).

### Tests for User Story 2 (write FIRST, must FAIL before implementation) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T013 [P] [US2] Write unit tests in `test/cow_list_test.dart` covering: loader detects the cow-number column by header (`Cow Number` variants per `contracts/file-formats.md` §2, normalized match `cownum`/`cow`), fallback to first column with valid ints sets `usedFallback = true`, duplicates deduplicated into `Set<int>`, non-integer cells collected as warnings, no valid numbers → `CowListError`; store round-trips save/load in a temp dir (JSON shape `{"cowNumbers": [...], "lastUpdated": "<ISO-8601>"}`), corrupt JSON loads as no-list without crashing

### Implementation for User Story 2

- [ ] T014 [P] [US2] Implement `lib/cow_list_loader.dart`: `loadCowListFromXlsx(String path) → CowListLoadResult` per `contracts/file-formats.md` §2 using the `excel` package. First non-empty row = headers, normalized with the same `normalizeHeader` rule; first header starting with `cownum` or equal to `cow` wins; otherwise fall back to first column containing a valid int and set the `usedFallback` flag; no column yields an int → `CowListError` ("no cow numbers found"). Skip blank rows, warn on non-integers, deduplicate (FR-005). Convert `excel` v4 `CellValue` subclasses to plain values with a small helper
- [ ] T015 [US2] Implement `lib/cow_list_store.dart`: `saveCowList(CowList)` and `getCowListFile() → CowList?` using `getApplicationSupportDirectory()/cow_list.json` via `path_provider` + `dart:convert` + `dart:io`. Missing file → null; corrupt JSON → null (never crash); overwrite happens ONLY after the new list fully validates (FR-008 — old file never destroyed by a failed import)
- [ ] T016 [US2] Make `test/cow_list_test.dart` pass (RED → GREEN)
- [ ] T017 [US2] Cow-list UI in `lib/main.dart` (extend T012's card, same file): on startup call `getCowListFile()` and set `activeCowList` (FR-006/FR-007 — auto-reuse after restart); "Update Cow List" button → pick `.xlsx` (`FileType.custom, allowedExtensions: ['xlsx']`) → `loadCowListFromXlsx` → if fallback column was used, inform the user (FR-004) → `saveCowList` → refresh card (count, "Last updated: <ts>", source saved/imported). On import failure: show the friendly `CowListError` message and KEEP the previous list (FR-008)

**Checkpoint**: Cow list persists across restarts; invalid imports are rejected without losing the active list.

---

## Phase 5: User Story 3 - Never lose track of missing cows (Priority: P1)

**Goal**: Cows on the active list that are absent from the report are shown to the user; Cancel produces no file, Continue exports only found cows.

**Independent Test**: In the app, convert with a list containing a cow absent from the report: the missing-cow dialog lists it, Cancel creates no file anywhere, Continue creates a file without that cow (quickstart.md §4 case D). No dialog when all cows are present.

### Implementation for User Story 3

- [ ] T018 [US3] Missing-cow flow in `lib/main.dart` [CONVERT] handler: first run a preview step in `Isolate.run` using the pure functions (`parseAlproReport` + `filterRecords` + `detectMissingCows` — no write); if `missing.isNotEmpty` show a confirm `AlertDialog` listing the missing cows with `[Cancel] [Continue]`; Cancel → abort, NO file created (FR-011); Continue → proceed to the save flow (US4). If zero records match after filtering, explain the situation with a typed error and create NO file (FR-021). Depends on T009 (converter), T012 (shell)

**Checkpoint**: Missing cows are never silently exported; Cancel guarantees no output file.

---

## Phase 6: User Story 4 - Choose where files go, every time (Priority: P2)

**Goal**: The user is always asked where to save; the file lands only in the chosen folder; failures are explained without stack traces.

**Independent Test**: Successful conversion → save dialog appears every time; file lands only in the chosen folder (quickstart.md §4 case E). Saving to a read-only/locked location shows a friendly message and lets the user retry.

### Implementation for User Story 4

- [ ] T019 [US4] Save flow in `lib/main.dart` (after T018's Continue): `FilePicker.platform.saveFile(fileName: 'DairySense_Import_<YYYY-MM-DD_HHmmss>.xlsx', type: FileType.custom, allowedExtensions: ['xlsx'])` (FR-015 — native dialog makes the name editable, no custom UI); then run the write in `Isolate.run` calling `runConversion` with the chosen path; existing-file collision → friendly `OutputWriteError` message and retry (FR-017). Depends on T018
- [ ] T020 [US4] Error handling in `lib/main.dart`: wrap every pipeline call and show `AlertDialog` with the typed message for `AlproParseError`, `CowListError`, `OutputWriteError`, `NoCowListError` ("Import a current cow list before converting."); NEVER show a raw stack trace to the user (FR-017, Principle IV). Depends on T019

**Checkpoint**: Folder picker appears on every conversion; all failures are user-friendly and retryable.

---

## Phase 7: Integration & Polish (Cross-Cutting Concerns)

**Purpose**: Real-fixture verification, full build, and validation gate

- [ ] T021 Write `test/integration_test.dart`: end-to-end `runConversion` over `test/fixtures/alpro_report.html` + `test/fixtures/current_cow_list.xlsx` → temp output; assert output row count = matching Alpro records, exported `CowNumber` set = intersection of report × list, `Milking Time` = total seconds, `Conductivity`/`temperature` = 0, header order exactly `Date, Session, UnitNo, CowNumber, Milking Time, Milk yield, Conductivity, temperature`. The test MUST skip gracefully (e.g. `markTestSkipped`) when fixture files are absent. When the real files arrive: inspect them per `contracts/file-formats.md`, adjust the header-name maps in `lib/alpro_parser.dart` and the constants in `lib/dairy_sense_writer.dart` until the integration test passes, and keep the files as regression fixtures (Constitution V/VI)
- [ ] T022 [P] Run `flutter analyze` and fix all reported issues
- [ ] T023 [P] Run `flutter test` — ALL tests green (unit + integration)
- [ ] T024 [P] Run `flutter build windows` — succeeds (requires VS2022 C++ workload per quickstart.md)
- [ ] T025 [P] Walk through the 5 manual acceptance cases (A–E) and edge checks from `quickstart.md` §4 against `build/windows/x64/runner/Release/alfa_milk.exe`; confirm Definition of Done per quickstart.md §6

**Checkpoint**: Feature is complete, built, and validated against the real files.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational (T004 models) completion
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational - Independent pipeline-wise (loader/store + own tests); its UI task T017 edits `lib/main.dart` after US1's T012
- **User Story 3 (P1)**: Depends on US1 (converter functions T009, shell T012) - same-file work in main.dart
- **User Story 4 (P2)**: Depends on US1 (T009, T012) and US3 (T018) - save flow runs after missing-cow confirmation

### Within Each User Story

- Tests MUST be written and FAIL before implementation (Constitution V: Red-Green-Refactor)
- Implementation order in US1: parser (T008) → writer (T010) → converter (T009, imports parser) → green (T011) → UI shell (T012)
- Core implementation before integration; story complete before moving to next priority

### Parallel Opportunities

- T002 and T001: different concerns, both in Setup
- T004 and T005: models.dart and fixtures dir are unrelated files
- T006 and T007: two independent test files for US1
- T008 and T010: different files, no interdependency (converter T009 joins them)
- T013: can start as soon as Foundational is done (independent test file)
- T014 and T015: loader and store are separate files
- T022–T025: independent validation commands in Polish phase

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together (write RED first):
Task: "Write unit tests for conversion core + writer round-trip in test/converter_test.dart"
Task: "Write unit tests for parser in test/alpro_parser_test.dart"

# Launch all models/implementations that don't depend on each other:
Task: "Implement lib/alpro_parser.dart"
Task: "Implement lib/dairy_sense_writer.dart"
# then (depends on both):
Task: "Implement lib/converter.dart"
```

## Parallel Example: User Story 2

```bash
# Tests and implementations are file-independent:
Task: "Write failing tests in test/cow_list_test.dart"
Task: "Implement lib/cow_list_loader.dart"
Task: "Implement lib/cow_list_store.dart"
# then: make tests green, then the main.dart card UI
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004–T005 — CRITICAL, blocks all stories)
3. Complete Phase 3: User Story 1 (T006–T012)
4. **STOP and VALIDATE**: `flutter test test/converter_test.dart test/alpro_parser_test.dart` + run the app and convert a sample report
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → MVP!
3. Add User Story 2 → Test independently (cow list persists, imports safe)
4. Add User Story 3 → Test independently (missing-cow safety)
5. Add User Story 4 → Test independently (save control + friendly errors)
6. Polish: integration test on real fixtures + build gate

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (pipeline + tests + UI shell)
   - Developer B: User Story 2 (loader/store/tests; UI card in main.dart after A's shell lands)
3. Developer A continues with User Story 3 then 4 (main.dart is one file — one owner)

---

## Notes

- **Cheap-model simplicity is the top priority** (user request): flat files, pre-specified signatures copied verbatim from plan.md, no new abstractions, no extra packages, one UI file
- Copy these helpers verbatim from plan.md into `converter.dart`: `normalizeHeader` and `normalizeCowNumber`; `durationToSeconds` reference is also in plan.md
- The 3 real fixture files are NOT in the repo yet — T021 handles them with a graceful skip; when they arrive, verify/adjust header maps per `contracts/file-formats.md` (Constitution Principle VI: never invent formats)
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Commit after each task or logical group
- `flutter analyze` must stay clean after every phase
