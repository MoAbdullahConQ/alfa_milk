import 'package:flutter_test/flutter_test.dart';

import 'package:alfa_milk/core/errors/custom_exceptions.dart';
import 'package:alfa_milk/core/utils/app_utils.dart';
import 'package:alfa_milk/features/home/data/data_sources/alpro_parser.dart';

String _reportHtml({
  String extraColumn = '',
  String headers = '',
  String dataRows = '''
      <tr>
        <td>5</td><td>UNIT1</td><td>12.5</td><td>00:03:00</td>
      </tr>
      <tr>
        <td>12</td><td>UNIT2</td><td>9.0</td><td>00:02:15</td>
      </tr>''',
  String dateLabel = '<td>Date</td><td>2026-08-09</td>',
  String sessionLabel = '<td>Session</td><td>AM</td>',
}) {
  final headerCells = headers.isEmpty
      ? '<th>Cow No.</th><th>MPC Address</th><th>Milk Yield</th><th>Milk Dur.</th>'
      : headers;
  return '''
<html>
<body>
  <table>
    <tr><td>Report</td><td>Daily</td></tr>
    <tr>$dateLabel</tr>
    <tr>$sessionLabel</tr>
  </table>
  <table>
    <tr>$headerCells$extraColumn</tr>
    $dataRows
  </table>
</body>
</html>
''';
}

void main() {
  group('normalizeHeader', () {
    test('lowercases and strips non-alphanumeric', () {
      expect(normalizeHeader('Cow No.'), 'cowno');
      expect(normalizeHeader('MPC Address'), 'mpcaddress');
      expect(normalizeHeader('Milk Dur.'), 'milkdur');
    });
  });

  group('parseAlproReport', () {
    test('parses records and extracts Date/Session', () {
      final report = parseAlproReport(_reportHtml());

      expect(report.date, '2026-08-09');
      expect(report.session, 'AM');
      expect(report.records, hasLength(2));

      final first = report.records.first;
      expect(first.cowNumber, 5);
      expect(first.unitNo, 'UNIT1');
      expect(first.milkYield, 12.5);
      expect(first.milkDur, '00:03:00');

      final second = report.records[1];
      expect(second.cowNumber, 12);
      expect(second.milkYield, 9.0);
    });

    test('throws AlproParseError naming a missing required column', () {
      expect(
        () => parseAlproReport(
          _reportHtml(
            headers:
                '<th>Cow No.</th><th>MPC Address</th><th>Milk Yield</th>',
          ),
        ),
        throwsA(isA<AlproParseError>()),
      );
    });

    test('fails the whole parse when a cow number is unparsable', () {
      final html = _reportHtml(
        dataRows: '''
      <tr><td>abc</td><td>UNIT1</td><td>12.5</td><td>00:03:00</td></tr>
      <tr><td>5</td><td>UNIT2</td><td>9.0</td><td>00:02:15</td></tr>''',
      );
      expect(() => parseAlproReport(html), throwsA(isA<AlproParseError>()));
    });

    test('skips rows missing Milk Yield or Milk Dur with a warning', () {
      final html = _reportHtml(
        dataRows: '''
      <tr><td>5</td><td>UNIT1</td><td>12.5</td><td>00:03:00</td></tr>
      <tr><td>12</td><td>UNIT2</td><td></td><td>00:02:15</td></tr>''',
      );
      final report = parseAlproReport(html);

      expect(report.records, hasLength(1));
      expect(report.records.first.cowNumber, 5);
      expect(report.warnings, isNotEmpty);
    });

    test('surfaces a warning when Date or Session label is missing', () {
      final report = parseAlproReport(
        _reportHtml(dateLabel: '', sessionLabel: ''),
      );
      expect(report.warnings, isNotEmpty);
    });
  });
}
