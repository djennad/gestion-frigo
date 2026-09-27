import 'dart:math';

/// Computes the EAN-13 check digit for the first 12 digits.
int ean13CheckDigit(String first12) {
  assert(first12.length == 12);
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final d = int.parse(first12[i]);
    sum += i.isEven ? d : d * 3;
  }
  return (10 - sum % 10) % 10;
}

bool isValidEan13(String code) {
  if (!RegExp(r'^\d{13}$').hasMatch(code)) return false;
  return ean13CheckDigit(code.substring(0, 12)) == int.parse(code[12]);
}

/// Generates an in-store EAN-13 code (prefix "2", reserved for internal use)
/// for products sold without a manufacturer barcode (bulk items, bread...).
String generateInternalBarcode([Random? random]) {
  final rnd = random ?? Random();
  final buffer = StringBuffer('2');
  for (var i = 0; i < 11; i++) {
    buffer.write(rnd.nextInt(10));
  }
  final first12 = buffer.toString();
  return '$first12${ean13CheckDigit(first12)}';
}
