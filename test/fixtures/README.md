# Test Fixtures

Real sample files for integration testing (T021). These are the real customer
files, kept as regression fixtures (Constitution V/VI). Do NOT modify them —
they come from the customer.

Present files:

- `alpro_report.html` — real Alpro milking report export (Session 1, 8-8; 147 records)
- `current_cow_list.xlsx` — the current DairySense cow-number list (41 cows)
- `dairy_sense_template.xlsx` — the DairySense import template (defines the
  exact header names and column order for output; == `Milking Import Format.xlsx`)

`test/integration_test.dart` runs end-to-end over these files (no longer
skipped). Additional real Alpro session reports are available under `E:\Alfa Milk\`
(`Session1 8-8.htm.html`, `Session2 7-8.htm.html`, `session 3 7-8.htm.html`).

## The three real reports span two dates

Those three reports are **not** three sessions of one day: `Session1 8-8` carries
the report date `26.08.08` (2026-08-08, the one checked in here as
`alpro_report.html`), while `Session2 7-8` and `session 3 7-8` are the previous
day. Two things follow.

- **It gates v1.2.0.** The first real multi-file batch a user runs would produce
  a **mixed-date workbook**, and nobody has confirmed real DairySense accepts
  one. That is acceptance cases **H–K**, defined in
  [`docs/alpro_dairysense_plan.md`](../../docs/alpro_dairysense_plan.md) §33.5.
  If DairySense rejects it, the merge design becomes one
  workbook per date.
- **They are the intended two-date regression input.** v1.2.0's Definition of
  Done (plan §32, Phase 2) requires all three files to be added here as a
  two-date fixture, proving rows sort date → session → source order and each row
  keeps its own file's `Date` and `Session`. Only `alpro_report.html`
  (= `Session1 8-8`) is checked in today.
