# ALFA MILK — Project Context

> **Purpose:** A single, self-contained orientation document for any developer, AI agent, chat model, or cloud service. Reading only this file should be enough to understand **what we're building, where we are, and what to do next**.
>
> **Authoritative source of truth is the repository itself** (code + Spec Kit artifacts under `specs/001-alpro-dairysense-converter/`). If this file conflicts with the repo, trust the repo and update this file.

---

## 1. Executive Summary

- **Project:** Alfa Milk — a local-first **Flutter desktop** app that converts an **Alpro** milking report (HTML) into a **DairySense** import file (XLSX), filtered by a user-managed **current cow list**.
- **No backend, login, or cloud** for the MVP. Runs offline on Windows.
- **Architecture:** feature-first Clean Architecture (`features/*/{data,domain,presentation}`) + shared `core/`; `flutter_bloc` Cubit for state; `dartz.Either<Failure, T>` at the data/domain boundary.
- **Status:** **Released as v1.0.0** (tag `v1.0.0`). All phases 1–7 complete (Setup, Foundation, US1–US4, integration/performance/polish).
- **Progress:** **27 of 27 tasks done** (see `tasks.md`). `flutter analyze` clean; `flutter test` green (52 unit + integration tests); `flutter build windows` succeeds; manual acceptance (quickstart §4 cases A–G) passed.
- **What comes next:** everything after v1.0.0 lives in **Part 2 of `docs/alpro_dairysense_plan.md`**, restructured into **eight independently shippable releases plus one non-shippable spike**: v1.1.0 distribution & cow-list durability → v1.2.0 multi-session merge → v1.3.0 live progress & drag and drop → v1.4.0 history/ledger/workbook inspector → **Phase 5S** `MilkIntegration.exe` spike → v1.5.0 one-click import → v1.6.0 history polish → v1.7.0 licensing → v1.8.0 UI redesign. **No post-1.0.0 code has been written yet** (§4).
- **Real files verified:** the user's real Alpro reports (`Session1 8-8`, `Session2 7-8`, `session 3 7-8`) parse and convert end-to-end (147 / 127 / 140 records) with real Date `26.08.08` and Session `1/2/3`; dry-cow rows export as `0`. Note these three **span two dates** — the reason acceptance cases H–K matter (§12).
- **Bug fixed (US4/T019):** the convert step no longer writes over the source report path — a native save dialog asks for the destination every time, and cancelling resets the UI cleanly.

---

## 2. What We're Building

### The conversion

```text
Alpro HTML (milking report)
        +
Current DairySense cow list (filter)
        ↓
Filtered/transformed DairySense XLSX
```

- **Alpro** exports milking data as HTML.
- **DairySense** manages the herd and imports milking data via a specific Excel format.
- The cow-number list is a **filter** (which cows to include), NOT a number-mapping.

### Tech stack

Flutter · Dart · Windows desktop · `html` (parse) · `excel` (read/write) · `file_picker` · `path_provider` · `path` · `flutter_bloc` · `dartz`. No code generation.

---

## 3. Where We Are (Phase-by-Phase)

| Phase | User story | Status | Tasks |
|------:|-----------|:------:|-------|
| 1 | Setup | ✅ done | T001–T003 |
| 2 | Foundational (models + fixtures dir) | ✅ done | T004–T005 |
| 3 | US1 — Convert report (pipeline + UI shell) | ✅ done | T006–T012 |
| 4 | US2 — Trust the cow list | ✅ done | T013–T017 |
| 5 | US3 — Never lose track of missing cows | ✅ done | T018 |
| 6 | US4 — Choose where files go, every time | ✅ done | T019–T020 |
| 7 | Integration, performance & polish | ✅ done | T021–T027 |

### Task list (authoritative: `tasks.md`)

- **Done (27 of 27):** T001–T027. No **v1.0.0** implementation work remains; post-1.0.0 work is planned in plan §32 and **not started** (§4). `tasks.md` covers v1.0.0 only.

### What's actually implemented in code

- **Pipeline (pure, testable, no UI):** Alpro HTML parser (header-index column mapping), cow-list loader/store (local persistence), filter by cow list, missing-cow detection, row builder (`Conductivity`/`temperature = 0`, `Milking Time` in seconds), XLSX writer (sheet `Sayfa1`, 8 official headers, real Date cells `dd/mm/yyyy` and Time cells `hh:mm`), `ConversionRepoImpl` running the pipeline in `Isolate.run`. Generated files verified to import into DairySense.
- **Domain:** `AlproRecord`, `AlproReport`, `CowList`, `DairySenseRow`, `ConversionResult`; use cases `FilterRecords`, `DetectMissingCows`, `BuildDairySenseRows`, `ConvertReport`.
- **UI:** `MainScreen` shell in `lib/main.dart`; cow-list card (count + last-updated + source, Update/import, restore-after-restart); report-convert view with `Select HTML file`, `CONVERT`, summary dialog.
- **US3 (T018):** `CONVERT` now runs a **preview** (parse + filter + detect missing) first; missing cows → `[Cancel] [Continue]` dialog (Cancel = no file, Continue = export found only); **no-cow-list guard** (`NoCowListError`) before anything; **zero-match guard** (FR-021, no file).
- **US4 (T019) — save flow:** native `FilePicker.saveFile` (static v11 API) asks for the destination **every** conversion; the source report is **never** used as the output path; default filename is 12-hour `DairySense_Import_<YYYY-MM-DD>_<H.mm am/pm>.xlsx`; write runs in `Isolate.run`; an existing/locked file → friendly `OutputWriteFailure` + retry loop. **Cancel-safe:** cancelling any dialog `reset()`s the cubit to idle (re-enables CONVERT, no file, no dialog). All dialog/summary text is `SelectableText` (copyable).
- **Real-file parser (verified 2026-08-10):** required headers matched by **prefix** (the real `Cow No.` header renders as `cowno1`); only a *truly empty* yield/dur cell is skipped — non-numeric yield and non-time duration (`-`, dry cows) are kept and exported as `0`; real **Date** (`26.08.08`) and **Session** (`1/2/3` from "Session N") extracted from the report text with label-based fallback. Session1=147, Session2=127, Session3=140 records end-to-end.

---

## 4. Next Action (post-release)

**v1.0.0 is done** (all 27 tasks, quality gates green) and **no v1.1+ code exists yet**. The next work is not "optional polish" any more: Part 2 of `docs/alpro_dairysense_plan.md` is the authoritative plan for it — §32 per-phase scope + Definition of Done, §35 DoD roll-up, §36 requirement→phase traceability, §37 defect register D1–D15.

**Start here: v1.1.0 — "Distribution & cow-list durability."** It is the only release with no open dependency, so it can begin immediately:

- Inno Setup installer (unsigned; the SmartScreen click-through is documented, not hidden).
- Fixed machine-wide data root `%ProgramData%\AlfaMilk\` (§30.15), with a one-time **copy**-migration out of `getApplicationSupportDirectory()` — the old file is copied, never moved.
- Atomic JSON writes (temp → `rename`) keeping a `.bak` of the last good list, plus **Restore previous list…** (§31.3).
- Nullable `lastUpdated` (so a restored/migrated list can say "unknown" rather than lie) + a ~30-day staleness warning; implausible-cow-number check on import.
- A rolling local support log (no network, ever — see §10 and plan §34).

Release order after that: v1.2.0 merge → v1.3.0 progress & drag-and-drop → v1.4.0 history/ledger/inspector → **Phase 5S spike** → v1.5.0 one-click import → v1.6.0 history polish → v1.7.0 licensing → v1.8.0 UI redesign (last by design). Two of these are gated — see §12.

**Release hygiene:** as of 2026-09-02 the local `main` is **5 commits ahead of the last-known `origin/main`** (`ccb229a`), all of them documentation. The `v1.0.0` tag exists locally; remote state was not checked (offline). **Do not push without explicit instruction.**

**Housekeeping:** keep `flutter analyze` / `flutter test` green after any change.

**Note:** drag-and-drop is **no longer a non-goal** — it is v1.3.0 scope. Still non-goals, and reaffirmed by plan §34: cloud sync / login / any network access, herd sync, Alpro↔DairySense number mapping, multiple farms or cow lists, invented conductivity/temperature values, rollback of an external import.

**Do not** restart Spec Kit from scratch, redesign the architecture, hard-code cow counts, or invent real-file structures.

---

## 5. Core Business Rules & Invariants (non-negotiable)

1. **Cow list is a filter, not a mapping.** Match rule: `Alpro Cow No. ∈ Current Cow List`. Row order irrelevant. Never create `Alpro→DairySense` number mappings.
2. **Cow count is variable.** Never hard-code a count (e.g. "41 cows"). Support any valid list size. ~147 sample records is not a limit.
3. **No cow list → no export.** If none is saved and user converts: stop, explain, ask to import. Do NOT export everything.
4. **Missing selected cows must be surfaced.** Never silently ignore them. Cancel ⇒ no output; Continue ⇒ export only found.
5. **Never invent measurements.** `Conductivity = 0`, `temperature = 0`.
6. **Output date comes from Alpro** (not `DateTime.now()`). Session comes from the report (not hard-coded "Session 1").
7. **Preserve previous valid cow list.** A failed import never destroys the saved list (overwrite only after validation).
8. **Output folder is user-selected every time** a workbook is generated (never silently to Downloads/Desktop/etc.).
9. **Keep conversion logic out of the UI** — pipeline must stay independently testable.
10. **Never invent file structures.** Real Alpro/DairySense files are the authority for formats.

---

## 6. Transformation Rules (field mapping)

| Output column | Source / rule |
|---|---|
| `Date` | Date from Alpro report |
| `Session` | Session from Alpro report |
| `UnitNo` | Alpro `MPC Address` |
| `CowNumber` | Alpro `Cow No.` |
| `Milking Time` | Alpro `Milk Dur.` (HH:MM:SS) → total seconds |
| `Milk yield` | Alpro `Milk Yield` |
| `Conductivity` | `0` |
| `temperature` | `0` |

**Milking Time** = hours×3600 + minutes×60 + seconds (e.g. `00:03:00` → `180`).

**Exact output XLSX shape** (sheet name/count, header row, column order, types, formatting) must match the real DairySense template — verify against the fixture, do not invent.

---

## 7. Complete Pipeline

```text
Select Alpro HTML → Parse → Validate → Load current cow list
  → (optionally import + validate + save new list) → Filter by Cow No.
  → Detect selected cows missing from Alpro → Ask user (Cancel/Continue)
  → Transform matching records → Validate output → Create XLSX
  → Ask user for output folder → Save → Show summary
```

Do not partially generate the workbook before validation completes.

---

## 8. Architecture & Code Layout

Feature-first Clean Architecture; dependencies point inward:

```text
main.dart (shell, composition root)
   → features/*/presentation   (bloc Cubit + views/widgets)
   → features/*/domain         (entities, repo abstraction, use cases)
   → features/*/data           (parsers, writer, repo impl, persistence)
   → external infrastructure
```

```text
lib/
├── main.dart
├── core/
│   ├── errors/            failures.dart, custom_exceptions.dart
│   ├── helper_functions/  error_dialog.dart, file_picker_helper.dart,
│   │                      show_conversion_summary.dart, show_missing_cows_dialog.dart
│   └── utils/             app_utils.dart (normalizeHeader, normalizeCowNumber, durationToSeconds)
└── features/
    ├── home/
    │   ├── data/data_sources/   alpro_parser.dart, dairy_sense_writer.dart
    │   ├── data/repos/          conversion_repo_impl.dart
    │   ├── domain/entities/     alpro_record, alpro_report, cow_list, dairy_sense_row, conversion_result
    │   ├── domain/repos/        conversion_repo.dart
    │   ├── domain/use_cases/    filter_records, detect_missing_cows, build_dairy_sense_rows, convert_report
    │   └── presentation/        manager/conversion_cubit/, views/main_screen.dart, views/widgets/
    └── cow_list/
        ├── data/   cow_list_loader.dart, cow_list_store.dart
        └── presentation/  cow_list_card.dart
```

**Error flow:** data source throws typed exception → `ConversionRepoImpl` catches → maps to `Failure` → returns `Either<Failure, T>` → use case/Cubit → UI. Never show raw stack traces.

**Persistence:** `getApplicationSupportDirectory()/cow_list.json` (cow numbers + last-updated). Survives restart. *(v1.1.0 moves this to a fixed `%ProgramData%\AlfaMilk\` with atomic writes and a `.bak` — plan §30.15 / §31.3. Not implemented yet.)*

---

## 9. Testing & Performance

- **Pipeline must be testable without the UI.** Unit tests cover parser, normalization, filtering, missing-cow detection, duration conversion, output mapping, `0` defaults, and workbook round-trip (`test/converter_test.dart`, `test/alpro_parser_test.dart`).
- **Cow-list tests (T013/T016):** done — loader/store round-trip in a temp dir (`test/cow_list_test.dart`).
- **Real-file integration (T021):** done — real fixtures shipped in `test/fixtures/` (`alpro_report.html`, `current_cow_list.xlsx`, `dairy_sense_template.xlsx`); `test/integration_test.dart` runs end-to-end, with a graceful skip if a fixture is absent.
- **Perf/non-mutation/large-list tests (T026/T027):** done — ~5,000-record responsiveness, empty-cow-set → `NoCowListFailure`, input bytes unchanged, several-thousand-cow list round-trip.
- **Performance:** supports several thousand records; heavy work runs in `Isolate.run` so the UI never blocks/freezes. Sample sizes are not limits.

---

## 10. MVP Non-Goals

Modifying Alpro/DairySense, cloud sync/login/database, herd sync, number mapping, automatic output-folder selection, invented conductivity/temperature values, manual mapping config.

For v1.1+ the list is restated and extended in plan **§34**: no network access of any kind (licensing included), no rollback of an external import, no cloud/online licence activation, no per-user data separation (`%ProgramData%\AlfaMilk\` is machine-wide by design), no multiple farms or cow lists. Drag-and-drop moved *out* of non-goals and into v1.3.0.

---

## 11. Fixture Requirement (very important)

Real supplied files to obtain and inspect: **Alpro HTML report**, **DairySense import Excel template**, **current DairySense cow-number Excel**. They are the authority for all format details. Do not invent sheet names, header rows, date formats, column positions, session values, or missing-value behavior. Keep them as regression fixtures.

---

## 12. Known Open Questions

1. Is the cow number always in one fixed Excel column, or auto-detected? *(resolved: loader auto-detects `Cow Number` header, falls back to first numeric column)*
2. What exact date format does DairySense require? *(pass-through of the Alpro Date token, e.g. `26.08.08` — not the computer's date)*
3. Can Alpro reports contain sessions other than "Session 1"? *(resolved: session is extracted from the report title "Session N" → `1`/`2`/`3`, not hard-coded)*
4–5. Behavior for missing/invalid `Milk Dur.` / `Milk Yield`? *(resolved in code: truly empty cells are skipped with a warning; non-empty non-numeric/dry-cow values like `-` are kept and exported as `0`)*
6. Are cow numbers always integers? *(assumed integer; normalization trims/parses)*
7. Required output filename? *(resolved: 12-hour `DairySense_Import_<YYYY-MM-DD>_<H.mm am/pm>.xlsx`, editable in the native save dialog)*
8. Does the workbook require a specific sheet name / multiple sheets? *(single sheet, 8 headers in fixed order; verify against template when available)*
9. Drag-and-drop support? *(not in scope for MVP)*
10. Preview filtered records before export? *(missing-cow preview implemented)*

Resolved items take precedence via the artifacts/implementation.

### Still open after v1.0.0 (only two — both owned, neither left to implementation time)

1. **Multi-date workbook acceptance — acceptance cases H–K. Blocks v1.2.0.** Does real DairySense accept **one workbook spanning more than one date**, attribute rows to the correct date *and* session (**I**), tolerate the same workbook imported twice (**J**, which also gates part of v1.5.0's `unknown` outcome), and reject the same cow twice in one `(Date, Session)` with `Hata: Subquery returns more than 1 row` (**K**)? It matters immediately because the three real reports span two dates. **No new code is needed** — the procedure is defined in plan §33.5, which is also where it says to record the outcome (as cases H–K in the quickstart, with the verified date in `contracts/file-formats.md`); neither file carries them yet. If DairySense rejects it, the merge design becomes one workbook per date.
2. **The `MilkIntegration.exe` control tree — owned by Phase 5S.** The spike answers plan §29.8's six unknowns on the real machine and decides whether v1.5.0's automation is Win32 window messaging (Tier 1) or `IUIAutomation` COM (Tier 2). It ships no product code.

Questions that *were* open in the v1.1 planning and are now **answered in plan §33** (do not re-litigate them): the data-root location (§33/§30.15 → `%ProgramData%\AlfaMilk\`), duplicate `(date, session)` handling (hard block, §33.2), licence states (two only: `licensed` / `blocked`, §33.4), and history retention (two caps, and it always asks, §33.6).

---

## 13. Definition of Done (MVP complete when)

Windows build succeeds; supplied Alpro parses; supplied cow list imports; any valid list size works; only selected cows exported; missing cows require confirmation; latest valid list persists; new list replaces old; failed update preserves old; correct workbook structure; `Conductivity=0`, `temperature=0`; duration→seconds correct; output folder chosen every time; invalid input never crashes; automated tests cover core rules; end-to-end conversion passes on real files; final quality gates pass.

**All of the above stays in force for every later release.** Each of v1.1.0–v1.8.0 adds its own Definition of Done on top; they are listed per phase in plan §32 and rolled up in **§35**.

---

## 14. How an Agent Should Continue

1. Read this file (orientation).
2. Read authoritative Spec Kit files: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, `tasks.md` (under `specs/001-alpro-dairysense-converter/`) — these are the **released v1.0.0 record**; for anything after v1.0.0 read **Part 2 of `docs/alpro_dairysense_plan.md`** (Part 1 is historical and must not be edited).
3. Inspect repo: `git status`, `lib/`, `test/`, `pubspec.yaml`.
4. Read `tasks.md` and trust its `[ ]`/`[X]` state over this file.
5. Inspect real fixtures before assuming file formats; don't invent them.
6. All v1.0.0 tasks (T001–T027) are complete. Post-1.0.0 work is **not** optional polish — it is the eight planned releases in plan §32; start at v1.1.0 (§4) and respect the two gates in §12.
7. Run `flutter analyze` + `flutter test` after each change; keep them green.

### Source-of-truth hierarchy

```text
1. Actual repository implementation/files
2. Current Spec Kit artifacts (v1.0.0) + Part 2 of docs/alpro_dairysense_plan.md (v1.1.0→v1.8.0)
3. Actual supplied fixtures
4. This project-context file
5. Older summaries / conversations
```

---

*Last updated: 2026-09-02 (docs reconciled to Part 2's eight-release plan; code still at v1.0.0).*
