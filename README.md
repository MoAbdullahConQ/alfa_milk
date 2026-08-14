# Alfa Milk — Alpro to DairySense Converter

A Flutter desktop application that converts Alpro milking reports into DairySense-compatible XLSX import files.

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

## Documentation

- [Spec](specs/001-alpro-dairysense-converter/spec.md) — Feature requirements and acceptance criteria
- [File Formats](specs/001-alpro-dairysense-converter/contracts/file-formats.md) — Alpro HTML and DairySense XLSX format details
- [Quickstart](specs/001-alpro-dairysense-converter/quickstart.md) — Build and manual acceptance walk-through
- [Tasks](specs/001-alpro-dairysense-converter/tasks.md) — Implementation tracker

## Status

**Beta** — All 4 user stories implemented. XLSX format verified against real DairySense import.
See [CHANGELOG.md](CHANGELOG.md) for details.
