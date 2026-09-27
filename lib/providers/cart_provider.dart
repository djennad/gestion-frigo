import 'package:flutter/foundation.dart';

import '../data/store_database.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale.dart';

/// Point-of-sale basket.
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  double get total => _items.fold(0, (s, i) => s + i.total);

  double get itemCount => _items.fold(0, (s, i) => s + i.quantity);

  /// Adds one unit of [product]. Returns false if stock would be exceeded.
  bool add(Product product, {double quantity = 1}) {
    final existing = _items.where((i) => i.product.id == product.id);
    final inCart = existing.isEmpty ? 0.0 : existing.first.quantity;
    if (inCart + quantity > product.quantity) return false;
    if (existing.isEmpty) {
      _items.add(CartItem(product: product, quantity: quantity));
    } else {
      existing.first.quantity += quantity;
    }
    notifyListeners();
    return true;
  }

  /// Sets the quantity of an item; removes it when [quantity] <= 0.
  bool setQuantity(CartItem item, double quantity) {
    if (quantity > item.product.quantity) return false;
    if (quantity <= 0) {
      _items.remove(item);
    } else {
      item.quantity = quantity;
    }
    notifyListeners();
    return true;
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Future<Sale> checkout(StoreDatabase db, {required double paid}) async {
    final saleItems = _items
        .map(
          (i) => SaleItem(
            productId: i.product.id!,
            productName: i.product.name,
            barcode: i.product.barcode,
            quantity: i.quantity,
            unitPrice: i.product.salePrice,
            purchasePrice: i.product.purchasePrice,
          ),
        )
        .toList();
    final sale = await db.recordSale(saleItems, paid: paid);
    clear();
    return sale;
  }
}
