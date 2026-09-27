import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_magasin/data/store_database.dart';
import 'package:gestion_magasin/models/product.dart';
import 'package:gestion_magasin/models/sale.dart';
import 'package:gestion_magasin/providers/cart_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late StoreDatabase db;

  setUp(() {
    db = StoreDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  Product milk({double qty = 10}) => Product(
    name: 'حليب كانديا',
    barcode: '6130000000017',
    category: 'حليب',
    purchasePrice: 110,
    salePrice: 130,
    quantity: qty,
    minQuantity: 3,
  );

  test('insert and find product by barcode', () async {
    await db.insertProduct(milk());
    final found = await db.getProductByBarcode('6130000000017');
    expect(found, isNotNull);
    expect(found!.name, 'حليب كانديا');
    expect(await db.getProductByBarcode('000'), isNull);
    expect((await db.getProducts(query: 'حليب')).length, 1);
  });

  test('duplicate barcode is rejected', () async {
    await db.insertProduct(milk());
    expect(
      () => db.insertProduct(milk()),
      throwsA(isA<DuplicateBarcodeException>()),
    );
  });

  test(
    'update keeps own barcode but rejects another product barcode',
    () async {
      final a = await db.insertProduct(milk());
      final b = await db.insertProduct(
        milk().copyWith(name: 'ياغورت', barcode: '6130000000024'),
      );
      await db.updateProduct(a.copyWith(salePrice: 140));
      expect((await db.getProductByBarcode(a.barcode))!.salePrice, 140);
      expect(
        () => db.updateProduct(b.copyWith(barcode: a.barcode)),
        throwsA(isA<DuplicateBarcodeException>()),
      );
    },
  );

  test('sale decrements stock and computes profit; cancel restores', () async {
    final p = await db.insertProduct(milk());
    final sale = await db.recordSale([
      SaleItem(
        productId: p.id!,
        productName: p.name,
        barcode: p.barcode,
        quantity: 4,
        unitPrice: p.salePrice,
        purchasePrice: p.purchasePrice,
      ),
    ], paid: 600);
    expect(sale.total, 520);
    expect(sale.profit, 80);
    expect(sale.change, 80);
    expect((await db.getProductByBarcode(p.barcode))!.quantity, 6);

    final stats = await db.getDashboardStats();
    expect(stats.todaySales, 520);
    expect(stats.todayProfit, 80);
    expect(stats.todayCount, 1);

    await db.deleteSale(sale.id!);
    expect((await db.getProductByBarcode(p.barcode))!.quantity, 10);
    expect(await db.getSales(), isEmpty);
  });

  test('sale exceeding stock fails and changes nothing', () async {
    final p = await db.insertProduct(milk(qty: 2));
    expect(
      () => db.recordSale([
        SaleItem(
          productId: p.id!,
          productName: p.name,
          barcode: p.barcode,
          quantity: 5,
          unitPrice: p.salePrice,
          purchasePrice: p.purchasePrice,
        ),
      ], paid: 1000),
      throwsA(isA<InsufficientStockException>()),
    );
    expect((await db.getProductByBarcode(p.barcode))!.quantity, 2);
    expect(await db.getSales(), isEmpty);
  });

  test('cart checkout through provider', () async {
    final p = await db.insertProduct(milk(qty: 3));
    final cart = CartProvider();
    expect(cart.add(p), isTrue);
    expect(cart.add(p, quantity: 2), isTrue);
    expect(cart.add(p), isFalse, reason: 'only 3 in stock');
    expect(cart.total, 390);
    final sale = await cart.checkout(db, paid: 400);
    expect(sale.items.single.quantity, 3);
    expect(cart.isEmpty, isTrue);
    expect((await db.getProductByBarcode(p.barcode))!.quantity, 0);
  });

  test('adjust stock and low stock stats', () async {
    final p = await db.insertProduct(milk(qty: 2));
    var stats = await db.getDashboardStats();
    expect(stats.lowStockCount, 1);
    await db.adjustStock(p.id!, 20);
    stats = await db.getDashboardStats();
    expect(stats.lowStockCount, 0);
    expect(stats.stockValue, 22 * 110);
  });
}
