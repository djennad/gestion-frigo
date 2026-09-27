import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_magasin/models/product.dart';
import 'package:gestion_magasin/utils/barcode_utils.dart';
import 'package:gestion_magasin/utils/formatters.dart';

void main() {
  test('EAN-13 check digit', () {
    expect(isValidEan13('4006381333931'), isTrue);
    expect(isValidEan13('4006381333932'), isFalse);
    expect(isValidEan13('abc'), isFalse);
  });

  test('generated internal barcodes are valid EAN-13 with prefix 2', () {
    final rnd = Random(42);
    for (var i = 0; i < 50; i++) {
      final code = generateInternalBarcode(rnd);
      expect(code, startsWith('2'));
      expect(isValidEan13(code), isTrue, reason: code);
    }
  });

  test('parseNumber accepts comma decimals', () {
    expect(parseNumber('12,5'), 12.5);
    expect(parseNumber(' 100 '), 100);
    expect(parseNumber(''), isNull);
    expect(parseNumber('x'), isNull);
  });

  test('product map round trip and expiry helpers', () {
    final now = DateTime(2026, 9, 27, 15);
    final p = Product(
      id: 3,
      name: 'ياغورت',
      barcode: '123',
      purchasePrice: 20,
      salePrice: 25,
      quantity: 4,
      minQuantity: 5,
      expiryDate: DateTime(2026, 10, 1),
    );
    final copy = Product.fromMap(p.toMap());
    expect(copy.name, p.name);
    expect(copy.expiryDate, p.expiryDate);
    expect(copy.isLowStock, isTrue);
    expect(copy.isExpiringWithin(7, now: now), isTrue);
    expect(copy.isExpired(now: now), isFalse);
    expect(copy.isExpired(now: DateTime(2026, 10, 2)), isTrue);
    expect(copy.copyWith(clearExpiry: true).expiryDate, isNull);
  });
}
