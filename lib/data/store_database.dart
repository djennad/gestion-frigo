import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import '../models/sale.dart';

class DuplicateBarcodeException implements Exception {
  final String barcode;
  DuplicateBarcodeException(this.barcode);

  @override
  String toString() => 'الباركود $barcode مستعمل لمنتج آخر';
}

class InsufficientStockException implements Exception {
  final String productName;
  final double available;
  InsufficientStockException(this.productName, this.available);

  @override
  String toString() =>
      'الكمية غير كافية للمنتج "$productName" (المتوفر: $available)';
}

class DashboardStats {
  final double todaySales;
  final double todayProfit;
  final int todayCount;
  final int productCount;
  final int lowStockCount;
  final int expiringCount;
  final double stockValue;

  const DashboardStats({
    this.todaySales = 0,
    this.todayProfit = 0,
    this.todayCount = 0,
    this.productCount = 0,
    this.lowStockCount = 0,
    this.expiringCount = 0,
    this.stockValue = 0,
  });
}

/// SQLite persistence for products and sales.
class StoreDatabase {
  static const _version = 1;

  final DatabaseFactory _factory;

  /// Database file path; defaults to `magasin.db` in the app databases folder.
  final String? path;
  Database? _db;

  StoreDatabase({DatabaseFactory? factory, this.path})
    : _factory = factory ?? databaseFactory;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _factory.openDatabase(
      path ?? p.join(await _factory.getDatabasesPath(), 'magasin.db'),
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
      ),
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT NOT NULL UNIQUE,
        category TEXT NOT NULL DEFAULT 'عام',
        unit TEXT NOT NULL DEFAULT 'قطعة',
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        quantity REAL NOT NULL DEFAULT 0,
        min_quantity REAL NOT NULL DEFAULT 0,
        expiry_date TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        profit REAL NOT NULL,
        paid REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        barcode TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        purchase_price REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_date ON sales(date)');
    await db.execute('CREATE INDEX idx_items_sale ON sale_items(sale_id)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---------------------------------------------------------------- Products

  Future<List<Product>> getProducts({String? query}) async {
    final db = await database;
    final rows = (query == null || query.trim().isEmpty)
        ? await db.query('products', orderBy: 'name COLLATE NOCASE')
        : await db.query(
            'products',
            where: 'name LIKE ? OR barcode LIKE ? OR category LIKE ?',
            whereArgs: List.filled(3, '%${query.trim()}%'),
            orderBy: 'name COLLATE NOCASE',
          );
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<Product> insertProduct(Product product) async {
    final db = await database;
    await _ensureBarcodeFree(db, product.barcode);
    final id = await db.insert('products', product.toMap()..remove('id'));
    return product.copyWith(id: id);
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await _ensureBarcodeFree(db, product.barcode, exceptId: product.id);
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Adds (or removes, if negative) [delta] units to a product's stock.
  Future<void> adjustStock(int productId, double delta) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET quantity = quantity + ? WHERE id = ?',
      [delta, productId],
    );
  }

  Future<void> _ensureBarcodeFree(
    DatabaseExecutor db,
    String barcode, {
    int? exceptId,
  }) async {
    final rows = await db.query(
      'products',
      columns: ['id'],
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (rows.any((r) => r['id'] != exceptId)) {
      throw DuplicateBarcodeException(barcode);
    }
  }

  // ------------------------------------------------------------------- Sales

  /// Records a sale and decrements stock atomically.
  Future<Sale> recordSale(List<SaleItem> items, {required double paid}) async {
    final db = await database;
    return db.transaction((txn) async {
      for (final item in items) {
        final rows = await txn.query(
          'products',
          columns: ['quantity'],
          where: 'id = ?',
          whereArgs: [item.productId],
        );
        final available = rows.isEmpty
            ? 0.0
            : (rows.first['quantity'] as num).toDouble();
        if (available < item.quantity) {
          throw InsufficientStockException(item.productName, available);
        }
      }
      final total = items.fold<double>(0, (s, i) => s + i.total);
      final profit = items.fold<double>(0, (s, i) => s + i.profit);
      final sale = Sale(
        date: DateTime.now(),
        total: total,
        profit: profit,
        paid: paid,
        items: items,
      );
      final saleId = await txn.insert('sales', sale.toMap());
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(saleId));
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      return Sale(
        id: saleId,
        date: sale.date,
        total: total,
        profit: profit,
        paid: paid,
        items: items,
      );
    });
  }

  Future<List<Sale>> getSales({DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('date < ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC',
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final rows = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return rows.map(SaleItem.fromMap).toList();
  }

  /// Cancels a sale and returns its items to stock.
  Future<void> deleteSale(int saleId) async {
    final db = await database;
    await db.transaction((txn) async {
      final items = await txn.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      for (final row in items) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          [row['quantity'], row['product_id']],
        );
      }
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });
  }

  // --------------------------------------------------------------- Dashboard

  Future<DashboardStats> getDashboardStats({DateTime? now}) async {
    final db = await database;
    final ref = now ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, ref.day);
    final end = start.add(const Duration(days: 1));
    final today = (await db.rawQuery(
      'SELECT COALESCE(SUM(total),0) t, COALESCE(SUM(profit),0) p, COUNT(*) c '
      'FROM sales WHERE date >= ? AND date < ?',
      [start.toIso8601String(), end.toIso8601String()],
    )).first;
    final stock = (await db.rawQuery(
      'SELECT COUNT(*) c, '
      'COALESCE(SUM(CASE WHEN quantity <= min_quantity THEN 1 ELSE 0 END),0) low, '
      'COALESCE(SUM(CASE WHEN expiry_date IS NOT NULL AND expiry_date < ? THEN 1 ELSE 0 END),0) exp, '
      'COALESCE(SUM(CASE WHEN quantity > 0 THEN quantity * purchase_price ELSE 0 END),0) val '
      'FROM products',
      [start.add(const Duration(days: 7)).toIso8601String()],
    )).first;
    return DashboardStats(
      todaySales: (today['t'] as num).toDouble(),
      todayProfit: (today['p'] as num).toDouble(),
      todayCount: today['c'] as int,
      productCount: stock['c'] as int,
      lowStockCount: (stock['low'] as num).toInt(),
      expiringCount: (stock['exp'] as num).toInt(),
      stockValue: (stock['val'] as num).toDouble(),
    );
  }
}
