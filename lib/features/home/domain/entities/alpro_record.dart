/// One milking event row parsed from the Alpro HTML table.
class AlproRecord {
  const AlproRecord({
    required this.cowNumber,
    this.unitNo = '',
    this.milkYield,
    this.milkDur,
  });

  final int cowNumber;
  final String unitNo;
  final double? milkYield;
  final String? milkDur;
}
