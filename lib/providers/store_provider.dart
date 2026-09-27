import 'package:flutter/foundation.dart';

import '../data/store_database.dart';
import '../models/product.dart';

/// Holds the product catalogue and dashboard figures, backed by [StoreDatabase].
class StoreProvider extends ChangeNotifier {
  final StoreDatabase db;

  StoreProvider(this.db);

  List<Product> _products = [];
  DashboardStats _stats = const DashboardStats();
  bool _loading = false;

  List<Product> get products => _products;
  DashboardStats get stats => _stats;
  bool get loading => _loading;

  List<Product> get lowStockProducts =>
      _products.where((p) => p.isLowStock).toList();

  List<Product> get expiringProducts =>
      _products.where((p) => p.isExpiringWithin(7)).toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));

  List<String> get categories {
    final set = _products.map((p) => p.category).toSet().toList()..sort();
    return set;
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _products = await db.getProducts();
      _stats = await db.getDashboardStats();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Product?> findByBarcode(String barcode) =>
      db.getProductByBarcode(barcode);

  Future<void> saveProduct(Product product) async {
    if (product.id == null) {
      await db.insertProduct(product);
    } else {
      await db.updateProduct(product);
    }
    await refresh();
  }

  Future<void> deleteProduct(Product product) async {
    await db.deleteProduct(product.id!);
    await refresh();
  }

  Future<void> adjustStock(Product product, double delta) async {
    await db.adjustStock(product.id!, delta);
    await refresh();
  }
}
