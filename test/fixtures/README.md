# Test Fixtures

Real sample files for integration testing (T021). These arrive later and are
kept as regression fixtures (Constitution V/VI). Do NOT invent these files —
they come from the customer.

Expected files:

- `alpro_report.html` — real Alpro milking report export
- `current_cow_list.xlsx` — the current DairySense cow-number list
- `dairy_sense_template.xlsx` — the DairySense import template (defines the
  exact header names and column order for output)

While these are absent, `test/integration_test.dart` skips gracefully. When they
arrive, verify/adjust the header maps in `alpro_parser.dart` and the constants
in `dairy_sense_writer.dart` per `contracts/file-formats.md`.
