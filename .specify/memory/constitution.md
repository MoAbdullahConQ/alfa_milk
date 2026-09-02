<!--
Sync Impact Report
- Version change: (template, unfilled) → 1.0.0
- Modified principles: none (initial ratification from docs/alpro_dairysense_plan.md)
- Added sections: Core Principles (6), Technology & Architecture Constraints,
  Development Workflow & Quality Gates, Governance
- Removed sections: none
- Deferred items: none (no placeholders intentionally retained)
- Source of adoption: docs/alpro_dairysense_plan.md
- Project status note (2026-08-14): founding feature ratified by this
  constitution was released as v1.0.0 — all 27 tasks in tasks.md complete,
  quality gates green, real-file end-to-end verified. Principles unchanged;
  no version bump required (informational only).
-->
# Alfa Milk Constitution

## Core Principles

### I. Local-First, No Backend
The application is local-only. The MVP MUST NOT require a backend, login or
account system, cloud database, or any network service. All persistence is
local and MUST survive application restarts and Windows reboots. Rationale:
the user's herd data is sensitive and must never leave the machine; a local
tool stays simple, fast, and reliable without infrastructure.

### II. Cow-List-Is-a-Filter (NON-NEGOTIABLE)
The current DairySense cow-number list is a filter, never a mapping. The cow
number is the matching key; row order is irrelevant. The list size is NOT
fixed and MUST NOT be hard-coded — it may grow or shrink over time and the
application MUST always use whatever valid cow numbers are in the latest
list. The application MUST NOT export all Alpro records when no cow list is
available; it MUST explain that a cow list is required and ask the user to
import one. Never create fake rows. Rationale: misinterpreting the list as a
mapping would silently corrupt herd data, the highest-cost failure mode.

### III. Deterministic, Testable Conversion Pipeline
The core application is a deterministic pipeline independent of the Flutter
UI: select source → parse → validate → load current cow list → filter →
detect missing cows → transform → validate output → generate workbook → save.
MUST NOT build the UI first and force conversion logic into it. The pipeline
MUST be independently testable without Flutter. The UI orchestrates the
pipeline and presents status, warnings, confirmations, and results only.

### IV. Fail-Safe Data Integrity
- A failed or invalid cow-list update MUST NEVER destroy the previous valid
  list.
- Missing selected cows MUST be detected and confirmed by the user: Cancel →
  no output; Continue → export only records found. Never silently ignore
  missing selected cows.
- The final workbook MUST NOT be partially created before all validation
  passes. Never create fake rows.
- The output folder MUST be chosen by the user every time; never silently use
  Downloads, Desktop, Documents, or the application folder.
- Invalid input MUST produce user-friendly messages; raw stack traces MUST
  NEVER be the primary message.

### V. Test-First with Regression Fixtures (NON-NEGOTIABLE)
Conversion logic MUST be developed test-first: failing tests approved before
implementation, Red-Green-Refactor strictly enforced. Unit tests cover HTML
parsing, header detection, cow-number normalization, filtering, missing-cow
detection, duration conversion, output mapping, and persistence. Integration
tests MUST use the supplied real files (Alpro HTML, cow-number Excel,
DairySense template) and the same files MUST be kept as regression fixtures.
Rationale: this converter lives and dies by exact field mapping; only real
data proves correctness.

### VI. Structure-Based Parsing; Never Invented Formats
Parsing MUST be based on document structure and column headers — locate the
relevant table and identify columns by header names instead of fragile
regex/position assumptions. Values MUST be normalized consistently across
inputs (trimming, deduplication, numeric identity preserved). The exact
structures of the Alpro HTML and the DairySense workbook MUST be inspected
from the supplied real files during planning; their structure MUST NOT be
invented or assumed. Dependencies MUST be maintained packages compatible with
the project's Flutter/Dart version; unnecessary dependencies MUST be avoided.

## Core Requirements (MVP)

- Target: Flutter/Dart, Windows desktop first.
- Input: Alpro HTML report; optional cow-list Excel (filter).
- Output: DairySense Excel with exact columns `Date`, `Session`, `UnitNo`,
  `CowNumber`, `Milking Time` (seconds), `Milk yield`, `Conductivity` (= 0),
  `temperature` (= 0) — exact workbook details verified against the real
  template.
- `Date` MUST be taken from the Alpro report, never the computer's current
  date. `Session` MUST be taken from the report, never hard-coded.
- Directories: parse, filter, transform, validate, then write. No partial
  workbook before validation.
- Performance: no artificial limit from the ~147 sample records; MUST handle
  several thousand records without freezing the Windows UI.

## Development Workflow & Quality Gates

- Definition of Done (every feature release): Windows build succeeds; all
  supplied Alpro HTML parses; cow list imports; only requested cows exported;
  missing cows blocked by confirmation; latest valid list persists and
  replaces the old one; failed updates preserve the old list; workbook
  structure correct; `Conductivity` = 0; `temperature` = 0; durations convert
  correctly to seconds; output folder always chosen; invalid input never
  crashes; automated tests cover transformation rules; end-to-end conversion
  passes with the supplied files.
- Unsolved parameters (cow-number column detection, date format, sessions,
  missing values handling, output filename, sheet name, drag-and-drop,
  preview) MUST be resolved during spec clarification before implementation.
- Non-goals for MVP: modifying Alpro or DairySense, cloud sync, login,
  mapping configuration, automatic output-folder selection, fake
  conductivity/temperature values.
- No code review may ship unless, and every review MUST verify, the above
  gates hold.

## Governance

This constitution tops all other practices and cannot be waived by the
workflow lifecycle; if a policy violates the constitution, the policy must be
amended here. Amendments require documentation, approval, and a proper
migration plan. Amendments follow semantic versioning: MAJOR for removed or
redefined principles, MINOR for new/mater-expanded guidance, PATCH for
clarifications and fixes. `docs/alpro_dairysense_plan.md` remains the source
of requirements for the founding feature and MUST stay in sync with this
document.

**Version**: 1.0.0 | **Ratified**: 2026-08-08 | **Last Amended**: 2026-08-08

**Project status**: The founding feature this constitution governs (Alpro →
DairySense converter) was **released as v1.0.0** on 2026-08-14. All principles
remain in force and unchanged; the quality gates below were met for the
release (Windows build succeeds, all real files parse/import, end-to-end
conversion passes on the supplied fixtures, and all quality gates verified
green). See `specs/001-alpro-dairysense-converter/tasks.md` (authoritative)
and `docs/.gpt/ALFA MILK — Project Context.md`. Post-v1.0.0 work is planned in
Part 2 of `docs/alpro_dairysense_plan.md` (eight releases plus one spike);
nothing in that plan amends this constitution — every principle above applies
unchanged to each release.