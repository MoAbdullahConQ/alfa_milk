# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A local-first Flutter **Windows desktop** app that converts an **Alpro** milking report (HTML)
into a **DairySense** import workbook (XLSX), filtered by a user-managed cow-number list.
No backend, no network, no login. Released as **v1.0.0**; the v1.1 plan ("Alfa Milk Pro":
multi-session merge, `MilkIntegration.exe` automation, history, licensing) is Part 2 of
`docs/alpro_dairysense_plan.md`.

## Commands

```bash
flutter pub get
flutter analyze                                    # must be clean
flutter test                                       # 52 tests, all green
flutter test test/converter_test.dart               # one file
flutter test --plain-name 'parses HH:MM:SS'         # one test/group by name
flutter build windows                              # Windows host only
flutter run -d windows                             # Windows host only
```

`flutter analyze` and `flutter test` run fine on Linux; only the `windows` targets need a
Windows host with Visual Studio 2022 + "Desktop development with C++".

`windows/CMakeLists.txt` deliberately pins the Windows SDK to `10.0.20348.0` (the
`10.0.22621.0` C++ component is incomplete on the build machine). Don't "fix" that line.

## Architecture

Feature-first Clean Architecture, `flutter_bloc` Cubit for state, `dartz.Either<Failure, T>`
at the data/domain boundary. No code generation, no DI container.

```
select HTML → parse → filter by cow list → detect missing cows → transform → validate → write XLSX → save
```

- The pipeline is **deterministic and Flutter-free**: `AlproParser` → `FilterRecordsUseCase` →
  `DetectMissingCowsUseCase` → `BuildDairySenseRowsUseCase` → `DairySenseWriter`, all wired in
  `ConversionRepoImpl._pipeline`. UI only orchestrates and presents.
- `_pipeline` and everything it calls (including the writer) are **synchronous on purpose** so the
  whole conversion runs in a single `Isolate.run` and never freezes the UI. Keep them sync.
- Errors: the pipeline throws typed exceptions from `core/errors/custom_exceptions.dart`;
  `ConversionRepoImpl` catches them and maps to `core/errors/failures.dart`. The UI shows
  `Failure.message` only — **never** a raw exception or stack trace.
- `MainScreen` (`features/home/presentation/views/main_screen.dart`) is the composition root:
  it builds `ConversionCubit(ConvertReportUseCase(ConversionRepoImpl()))` and owns UI-local
  state (picked HTML path, active cow list). Use cases and the repo default-construct their
  collaborators, with optional constructor params for test injection.

Layout quirks worth knowing (the README's tree is aspirational):
- The `CowList` entity lives in `features/home/domain/entities/cow_list.dart`, not in the
  `cow_list` feature. `features/cow_list/` has **only** `data/` (loader + store).
- `CowListCard` lives under `features/home/presentation/views/widgets/`.

## Invariants that span files

These come from `.specify/memory/constitution.md` and were verified against real customer files
and the real DairySense software. Breaking one silently corrupts herd data.

- **The cow list is a filter, never a mapping.** The cow number is the matching key; row order is
  irrelevant. Its size is unbounded and must never be hard-coded. With no list, explain and export
  nothing — never fall back to exporting all records, never invent rows.
- **`Date` and `Session` come from the report**, never `DateTime.now()`. (The *output filename*
  does use wall-clock time — that's the one intentional exception.)
- `Conductivity` and `temperature` are always `0`.
- **Milking Time is deliberately remapped**: `_milkingTimeValue` writes
  `TimeCellValue(hour: minutes, minute: seconds)` because DairySense reads the displayed `hh:mm`
  as minutes:seconds (`225 s → 03:45`). This looks like a bug and is not.
- Output workbook constants (`dairySenseSheetName = 'Sayfa1'` and the 8 exact headers, including
  `'CowNumber - in dairysense number-'` and `'Milking Time -in seconds-'`) live at the top of
  `dairy_sense_writer.dart` as the single source of truth, and are asserted by
  `test/integration_test.dart`. Change them only with a verified real-DairySense import.
- **Parsing is structure/header-based, and header matching is prefix-based.** `normalizeHeader`
  lowercases and strips non-alphanumerics; the real report's `Cow No.` carries a sort indicator
  and normalizes to `cowno1`, and the yield header appears as `milyield`/`milyeild`/`milkyield`.
- Row handling: a **truly empty** Milk Yield or Milk Dur. → skip with a warning; a **non-empty**
  non-numeric value (`-`, a dry cow) → keep and export as `0`. An unparsable cow number fails the
  whole parse.
- The output path is chosen by the user **every time** via the native save dialog; never derive it
  from the source report, never default to Downloads/Desktop/Documents/app folder. Cancelling any
  step calls `cubit.reset()` so CONVERT re-enables and no file exists.
- `CowListStore` overwrites `cow_list.json` only after the new list fully validates (a failed
  update must preserve the previous list), and a missing/corrupt file yields `null` — never a crash.
- All dialog text uses `SelectableText` (copyable) — that's acceptance case G.

## Testing conventions

- Test-first is non-negotiable per the constitution (Principle V): write the failing test, then
  implement.
- No mocking framework. Tests construct real objects and build XLSX inputs inline with the `excel`
  package; `CowListStore` tests stub `path_provider` via `path_provider_platform_interface`.
- `test/fixtures/` holds **real customer files** (`alpro_report.html` 147 records,
  `current_cow_list.xlsx` 41 cows, `dairy_sense_template.xlsx`). Do not modify them. Keep
  `test/integration_test.dart` skipping gracefully when fixtures are absent.
- Test names carry their task/requirement IDs (`T021`, `FR-014`) — keep that when adding tests so
  they stay traceable to the spec.

## Spec Kit workflow

The repo is driven by Spec Kit (`.specify/`, `.opencode/commands/speckit.*`).

- `.specify/memory/constitution.md` — governing principles; tops all other practices.
- `specs/001-alpro-dairysense-converter/` — authoritative artifacts: `spec.md`, `plan.md`,
  `data-model.md`, `contracts/file-formats.md`, `quickstart.md` (manual acceptance cases A–G),
  and `tasks.md` (the authoritative task tracker — all 27 done).
- `contracts/file-formats.md` must be updated whenever an input/output format understanding
  changes; it records what was verified against real files and when.
- `docs/alpro_dairysense_plan.md`: **Part 1 is historical — do not edit it**; Part 2 is the v1.1
  plan. Orientation notes live in `docs/.gpt/` (other docs refer to
  `docs/ALFA MILK — Project Context.md`; the file actually sits under `docs/.gpt/`).
