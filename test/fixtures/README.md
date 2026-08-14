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
