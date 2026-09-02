# Alfa Milk — Alpro to DairySense Converter

A Flutter desktop application that converts Alpro milking reports into DairySense-compatible XLSX import files.

> **Released — v1.0.0** (tag `v1.0.0`, pushed to `origin`): all 4 user stories implemented and verified against real DairySense software. All 27 tasks complete; `flutter analyze` clean, `flutter test` green (52 passing), `flutter build windows` succeeds, and manual acceptance cases A–G passed.
>
> **Next:** v1.1.0 — see [Roadmap](#roadmap). No v1.1 code has been written yet.

## Features

- **Convert Reports**: Parse Alpro HTML reports and generate XLSX files ready for DairySense import.
- **Cow List Management**: Import and persist a trusted farm cow list with automatic column detection.
- **Missing-Cow Preview**: See which cows are in the report but not in your list before converting.
- **Native Save Dialog**: Choose the output location and filename every time.

## Project Structure

```
lib/
  core/
    errors/          # Failure classes and custom exceptions
    utils/           # Shared helpers (normalizeCowNumber, durationToSeconds, etc.)
  features/
    home/            # Report conversion (US1, US3, US4)
      data/          # AlproParser, DairySenseWriter, ConversionRepoImpl
      domain/        # Entities, use cases, repo interface
      presentation/  # Cubit, views, widgets
    cow_list/        # Cow list management (US2)
      data/          # CowListLoader, CowListStore
      domain/        # CowList entity
      presentation/  # CowListCard widget
```

## Getting Started

```bash
flutter pub get
flutter run
```

## Testing

```bash
flutter test
flutter analyze
```

## Build

```bash
flutter build windows
```

## Roadmap

Work after v1.0.0 is planned as **eight independently shippable releases plus one
non-shippable spike**, each with its own goal, scope and Definition of Done. The
authoritative source is Part 2 of
[`docs/alpro_dairysense_plan.md`](docs/alpro_dairysense_plan.md) (§32 for the phases,
§35 for the roll-up, §36 for traceability, §37 for the defect register).

| Release | Theme | Notes |
|---|---|---|
| v1.1.0 | Distribution & cow-list durability | Inno Setup installer, fixed `%ProgramData%\AlfaMilk\` data root, atomic writes + `.bak`, **Restore previous list…**, cow-list staleness warning, support log |
| v1.2.0 | Multi-session merge | Any number of Alpro HTML files → one workbook, sorted date → session → source order. **Gated on acceptance cases H–K** (see below) |
| v1.3.0 | Live progress & drag and drop | Per-file/per-phase progress out of the batch isolate; multi-file dropzone |
| v1.4.0 | History, ledger & workbook inspector | `NavigationRail` shell, history page, import ledger, read-back of any DairySense workbook |
| — (5S) | `MilkIntegration.exe` spike | **Not a release** — answers §29.8's six unknowns on the real machine; produces no shippable code |
| v1.5.0 | One-click DairySense import | In-process Dart FFI automation, four outcomes (`success` / `failure` / `unknown` / `precondition_failed`), manual fallback always offered |
| v1.6.0 | History polish | Retention cap (always asks), history export, diagnostics zip, read-only licence request-code readout |
| v1.7.0 | Licensing | Hardware-locked activation: two states only, `licensed` / `blocked`; never destroys local data |
| v1.8.0 | UI redesign, dashboard & dark mode | Deliberately last, designed around the finished screens |

Two questions stay open and are not left to implementation time:

- **Acceptance cases H–K** — does real DairySense accept one workbook containing more
  than one date, and attribute rows to the right date and session? This **blocks
  v1.2.0**; the procedure is defined in
  [plan §33.5](docs/alpro_dairysense_plan.md) and needs no new code.
- **`MilkIntegration.exe` control tree** — owned by the 5S spike; it decides whether the
  automation is Win32 window messaging or `IUIAutomation` COM.

## Documentation

- [Spec](specs/001-alpro-dairysense-converter/spec.md) — Feature requirements and acceptance criteria
- [File Formats](specs/001-alpro-dairysense-converter/contracts/file-formats.md) — Alpro HTML and DairySense XLSX format details
- [Quickstart](specs/001-alpro-dairysense-converter/quickstart.md) — Build and manual acceptance walk-through (cases A–G, shipped in v1.0.0)
- [Tasks](specs/001-alpro-dairysense-converter/tasks.md) — Implementation tracker (v1.0.0, all 27 done)
- [Plan](docs/alpro_dairysense_plan.md) — Part 1 is the historical v1.0 plan (do not edit); Part 2 is the authoritative v1.1.0 → v1.8.0 plan

## Status

**Released — v1.0.0** (tag `v1.0.0`, pushed to `origin`). All 4 user stories implemented and
verified against real DairySense software. All 27 tasks in
[`tasks.md`](specs/001-alpro-dairysense-converter/tasks.md) are complete; `flutter analyze`
is clean, `flutter test` is green (52 passing tests), `flutter build windows` succeeds, and
manual acceptance cases A–G passed on the built EXE. See [CHANGELOG.md](CHANGELOG.md) for details.

Nothing from the [Roadmap](#roadmap) has been implemented yet. The next release, v1.1.0, has
no dependency on the two open questions above and can start immediately; v1.2.0 cannot start
until cases H–K are recorded.
