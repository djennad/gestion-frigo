import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_magasin/data/store_database.dart';
import 'package:gestion_magasin/main.dart';
import 'package:gestion_magasin/models/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('app starts and navigates between tabs', (tester) async {
    final db = StoreDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await tester.runAsync(
      () => db.insertProduct(
        const Product(
          name: 'سكر',
          barcode: '111',
          purchasePrice: 90,
          salePrice: 100,
          quantity: 1,
          minQuantity: 5,
        ),
      ),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GestionMagasinApp(db: db));
    // sqflite ffi runs on a real isolate: let it finish the initial load.
    for (
      var i = 0;
      i < 20 && find.text('مخزون ناقص (1)').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    expect(find.text('مبيعات اليوم'), findsOneWidget);
    expect(find.text('مخزون ناقص (1)'), findsOneWidget);

    await tester.tap(find.text('المنتجات'));
    await tester.pumpAndSettle();
    expect(find.text('سكر'), findsWidgets);

    await tester.tap(find.text('البيع'));
    await tester.pumpAndSettle();
    expect(find.textContaining('السلة فارغة'), findsOneWidget);

    await tester.runAsync(db.close);
  });
}
