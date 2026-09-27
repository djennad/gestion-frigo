import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00', 'en');
final _qty = NumberFormat('#,##0.###', 'en');
final _date = DateFormat('yyyy/MM/dd');
final _dateTime = DateFormat('yyyy/MM/dd HH:mm');

String formatMoney(double value) => '${_money.format(value)} دج';

String formatQty(double value) => _qty.format(value);

String formatDate(DateTime date) => _date.format(date);

String formatDateTime(DateTime date) => _dateTime.format(date);

/// Parses user input accepting both "," and "." as decimal separator.
double? parseNumber(String? text) {
  if (text == null) return null;
  final cleaned = text.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
