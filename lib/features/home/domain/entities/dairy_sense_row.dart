/// One output row for the workbook.
class DairySenseRow {
  const DairySenseRow({
    required this.date,
    required this.session,
    required this.unitNo,
    required this.cowNumber,
    required this.milkingTime,
    required this.milkYield,
    this.conductivity = 0,
    this.temperature = 0,
  });

  final String date;
  final String session;
  final String unitNo;
  final int cowNumber;
  final int milkingTime;
  final double milkYield;
  final int conductivity;
  final int temperature;
}
