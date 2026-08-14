# Project Handoff Summary — Alpro → DairySense Flutter Converter

## Project Goal

I am building a **Flutter desktop application**, mainly targeting **Windows**, that acts as a bridge between two existing systems:

- **Alpro** — provides animal/milking data as an HTML report.
- **DairySense** — manages the herd and requires a specific Excel format for importing milking data.

The Flutter app must take an Alpro HTML report, extract its data, filter the cows based on a separate Excel file containing the **current DairySense cow numbers**, and generate a new Excel file compatible with DairySense.

---

## Important Business Logic

### The Cow Number Excel Is a Filter List

The cow-number Excel file is **NOT a mapping**.

It does NOT mean:

```text
Alpro Cow Number → DairySense Cow Number
```

Instead, it is simply a list of the cow numbers that I currently want to extract from the Alpro report.

Example:

```text
Alpro HTML contains:
5
8
12
15
20
31
44
...

Current DairySense cow list contains:
5
12
20
31
44
...

Output:
Only records for:
5
12
20
31
44
...
```

The application reads all Alpro records and then filters them using:

```text
Alpro Cow No. ∈ Current Cow List
```

The **cow number itself** is the matching key. Row order does not matter.

---

## VERY IMPORTANT: Cow Count Is NOT Fixed

Do NOT mention or hard-code a fixed number such as 41.

The Excel file I provided currently contains a certain number of cows, but this number can:

- increase
- decrease
- change completely
- vary from one file to another

The application must support **any valid number of cow numbers**.

For example, the list might contain 10, 41, 100, 200, etc.

The requirement is:

> The number of cows in the cow-list Excel file is variable and must never be hard-coded.

---

## Current Cow List Behavior

The cow-number Excel file is optional during normal conversion.

### If the user imports a new cow list

1. Read the Excel file.
2. Validate it.
3. Extract the cow numbers.
4. Save it locally.
5. Replace the previously saved/current list.
6. Use the new list for the current conversion.

### If the user does NOT import a new list

Use the **last successfully saved cow list** automatically.

Therefore:

```text
New list supplied
    ↓
Validate
    ↓
Save as current list
    ↓
Use it

No new list supplied
    ↓
Use last saved list
```

### First-time use

If no cow list has ever been saved and the user tries to convert without providing one:

- Do not export all Alpro cows.
- Tell the user that a cow list is required.
- Ask them to import one.

### Failed update

If a new cow-list Excel is invalid:

- Do NOT replace the previous valid list.
- Keep the previous list intact.

---

## Missing Cow Behavior

If a cow exists in the current cow-list Excel but is not found in the Alpro HTML:

**Ask the user before continuing.**

Example:

```text
Some selected cows were not found in the Alpro report.

Missing:
44

[ Cancel ] [ Continue ]
```

Behavior:

- **Cancel:** stop conversion and do not generate the output.
- **Continue:** export only the cows that were actually found.
- Never create fake rows.
- Never silently ignore missing selected cows.

---

## Input 1 — Alpro HTML

The Alpro report contains animal/milking records.

The sample report I provided contains around 147 records, but this number is also **not a fixed requirement**.

Relevant columns identified so far include:

- `Cow No.`
- `Group No.`
- `Transp. No.`
- `Milk Yield`
- `Corrected Yield`
- `ID Time`
- `Milk Start Time`
- `Milk Dur.`
- `MPC Address`
- `Storage Position`

The application should parse the HTML structurally.

Do not rely on fragile regex or fixed row positions if the data can be identified using HTML tables and column headers.

The parser should:

1. Read the HTML.
2. Locate the relevant table.
3. Detect the columns by their headers.
4. Extract records.
5. Normalize/validate values.
6. Produce domain objects independent of Flutter UI.

---

## Input 2 — Cow Number Excel

This Excel file contains the **current DairySense cow numbers**.

Its only purpose is to determine which Alpro records should be exported.

Conceptually:

```text
Cow Number
-----------
5
12
20
31
44
...
```

The number of rows is variable.

The application should:

- ignore blank rows
- detect invalid values
- normalize values consistently
- deduplicate internally
- use the cow number as the filtering key

The exact structure of the provided sample workbook should be inspected during the Spec Kit research/planning phase.

---

## Input 3 — DairySense Excel Template

I provided a sample DairySense Excel template.

The generated output must follow the actual structure of this template.

Known required output columns are:

| DairySense Column | Source / Rule |
|---|---|
| `Date` | Date from Alpro report |
| `Session` | Session from Alpro report |
| `UnitNo` | Alpro `MPC Address` |
| `CowNumber` | Alpro `Cow No.` |
| `Milking Time` | Alpro `Milk Dur.` converted to seconds |
| `Milk yield` | Alpro `Milk Yield` |
| `Conductivity` | Always `0` |
| `temperature` | Always `0` |

Important:

The actual DairySense workbook/template should be treated as the **source of truth**.

During Spec Kit research, inspect the real workbook and verify:

- Sheet name
- Header row
- Column order
- Data types
- Formatting
- Additional rows/cells
- Number of sheets
- Any other structure required by DairySense

---

## Transformation Rules

### CowNumber

```text
Alpro Cow No. → DairySense CowNumber
```

### Milk yield

```text
Alpro Milk Yield → DairySense Milk yield
```

### UnitNo

```text
Alpro MPC Address → DairySense UnitNo
```

### Milking Time

`Milk Dur.` is formatted like:

```text
00:03:00
```

It must become total seconds:

```text
180
```

Formula:

```text
hours × 3600 + minutes × 60 + seconds
```

### Conductivity

Always:

```text
0
```

### temperature

Always:

```text
0
```

These values are not available in the current Alpro report, so they must not be invented.

### Date

Extract the actual report date from Alpro.

Do not use today's date.

### Session

Extract the session from the Alpro report.

Do not blindly hard-code `Session 1` if the report can contain other sessions.

---

## Complete Conversion Flow

```text
Select Alpro HTML
        ↓
Parse HTML
        ↓
Load last saved cow list
        ↓
Optionally import a new cow list
        ↓
Validate/save new list if supplied
        ↓
Filter Alpro records by Cow No.
        ↓
Detect missing selected cows
        ↓
Ask user whether to continue
        ↓
Transform matching records
        ↓
Validate output
        ↓
Generate DairySense XLSX
        ↓
Ask user for output folder
        ↓
Save XLSX
        ↓
Show conversion summary
```

---

## Output Folder

The app must **ask the user for the destination folder every time** a file is generated.

Do not automatically save to:

- Downloads
- Desktop
- Documents
- Application directory

unless the user explicitly chooses that location.

A possible filename is:

```text
DairySense_Import_YYYY-MM-DD.xlsx
```

The exact filename convention can be clarified later.

---

## UI Direction

The app should be a simple Windows desktop utility.

Possible main screen:

```text
ALPRO → DAIRYSENSE

Alpro HTML
[ Select HTML File ]

Current Cow List
✓ <variable count> cows loaded
Last updated: <date/time>

[ Update Cow List ]

[ CONVERT ]

Status:
Alpro records: <count>
Selected cows: <count>
Found: <count>
Missing: <count>
```

The UI must make it obvious:

- which HTML file is selected
- which cow list is currently active
- when the list was last updated
- whether the saved list is being reused
- how many records were found
- how many selected cows are missing

---

## Persistence

Persist locally:

```text
Current cow numbers
Last updated timestamp
```

The saved list must survive:

- application restart
- Windows reboot

No cloud database is needed for MVP.

---

## Architecture Direction

Separate UI from business logic.

Recommended conceptual structure:

```text
Presentation
    ↓
Application / Use Cases
    ↓
Domain
    ↓
Infrastructure
```

Possible domain models:

- `AlproRecord`
- `CowNumber`
- `CowList`
- `DairySenseRecord`
- `ConversionResult`
- `ConversionWarning`

Possible use cases:

- Import Cow List
- Load Current Cow List
- Parse Alpro Report
- Filter Records
- Detect Missing Cows
- Convert Records
- Generate DairySense Workbook
- Save Output

Infrastructure:

- HTML parser
- Excel reader
- Excel writer
- Local persistence
- Windows file/folder picker

The exact Flutter packages/architecture should be researched during Spec Kit planning instead of being assumed now.

---

## Target Platform

The application is a:

**Flutter desktop app, primarily for Windows.**

Windows is the main target for the MVP.

---

## Testing Requirements

The core conversion pipeline must be independently testable.

Unit tests should cover:

- HTML parsing
- header detection
- cow-number normalization
- filtering
- missing-cow detection
- duration conversion
- output mapping
- `Conductivity = 0`
- `temperature = 0`
- duplicate handling
- invalid values
- cow-list persistence

Integration testing should use the actual supplied sample files:

```text
Alpro HTML
+
Cow Number Excel
+
DairySense Template
↓
Generated DairySense XLSX
```

Verify:

- correct selected cows
- correct filtering
- correct milk yield
- correct UnitNo
- correct milking time
- correct date/session
- conductivity = 0
- temperature = 0
- correct workbook structure

The supplied files should become regression fixtures.

---

## Performance

Do not hard-code limits based on the current sample sizes.

The current Alpro sample has around 147 records, but future reports may contain more or fewer records.

The application should comfortably handle several thousand records.

Avoid freezing the Windows UI during parsing or Excel generation.

---

## MVP Non-Goals

Do NOT implement in MVP:

- modifying Alpro
- modifying DairySense
- cloud synchronization
- login/accounts
- cloud database
- automatic herd synchronization
- Alpro-to-DairySense number mapping
- automatic output folder selection
- invented measurement values
- manual cow-number mappings

---

## Future Possibilities

The architecture should allow future support for:

- multiple Alpro report formats
- multiple DairySense formats
- multiple farm profiles
- multiple saved cow lists
- configurable field mappings
- additional Alpro measurements
- preview before export
- conversion history

These are future ideas, not MVP requirements.

---

## Spec Kit

I plan to implement this project using **GitHub Spec Kit**.

The intended workflow is:

```text
/speckit.constitution
        ↓
/speckit.specify
        ↓
/speckit.clarify
        ↓
/speckit.plan
        ↓
/speckit.checklist
        ↓
/speckit.tasks
        ↓
/speckit.analyze
        ↓
/speckit.implement
        ↓
/speckit.converge
```

The goal is to make the requirements explicit before implementation and avoid assumptions about the real Excel/HTML structures.

---

## Current Planning Status

A `plan.md` was created for the project.

The plan includes:

- project overview
- business rules
- cow-list behavior
- missing-cow behavior
- HTML parsing
- Excel filtering
- DairySense output mapping
- persistence
- Windows UI
- architecture
- validation
- testing
- MVP
- acceptance scenarios
- open clarification questions
- Spec Kit workflow

One important correction was made after the initial plan:

**The cow count must never be described as fixed.**

The current sample happened to contain a certain number of cow numbers, but the number can change at any time.

---

## Important Clarification Already Answered

The user confirmed:

```text
Missing selected cow:
→ Ask the user before continuing.

Target platform:
→ Flutter app, mainly Windows desktop.

Output location:
→ Ask for the destination folder every time.

Conductivity:
→ 0.

temperature:
→ 0.
```

---

## Remaining Clarifications

Before final implementation planning, the following should still be clarified:

1. Is the cow number always in a fixed Excel column/header?
2. What exact Date format does DairySense require?
3. Can Alpro contain sessions other than Session 1?
4. What should happen when `Milk Dur.` is missing?
5. What should happen when `Milk Yield` is invalid/missing?
6. Are cow numbers always integers?
7. Is there a required output filename?
8. Does the DairySense workbook require a specific sheet name or multiple sheets?
9. Should drag-and-drop be supported?
10. Should the user preview the filtered records before export?

---

## Where We Are Now

The business concept and main conversion rules are defined.

The next step is **NOT to start coding blindly**.

The next step should be:

1. Inspect the actual supplied files.
2. Use Spec Kit to perform clarification/research.
3. Verify the real Alpro HTML structure.
4. Verify the real cow-list Excel structure.
5. Verify the exact DairySense Excel template structure.
6. Resolve the remaining open questions.
7. Generate the final Spec Kit specification and implementation plan.
8. Generate tasks.
9. Implement the Flutter Windows application.
10. Test the full real-file conversion pipeline.

When continuing in a new chat, treat this document as the authoritative project context and continue from **Spec Kit clarification/research and final planning**, not from the beginning.