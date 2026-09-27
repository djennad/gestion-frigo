class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final String barcode;
  final double quantity;
  final double unitPrice;
  final double purchasePrice;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.purchasePrice,
  });

  double get total => quantity * unitPrice;

  double get profit => quantity * (unitPrice - purchasePrice);

  Map<String, Object?> toMap(int saleId) => {
    'sale_id': saleId,
    'product_id': productId,
    'product_name': productName,
    'barcode': barcode,
    'quantity': quantity,
    'unit_price': unitPrice,
    'purchase_price': purchasePrice,
  };

  factory SaleItem.fromMap(Map<String, Object?> map) => SaleItem(
    id: map['id'] as int?,
    saleId: map['sale_id'] as int?,
    productId: map['product_id'] as int,
    productName: map['product_name'] as String,
    barcode: map['barcode'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unitPrice: (map['unit_price'] as num).toDouble(),
    purchasePrice: (map['purchase_price'] as num).toDouble(),
  );
}

class Sale {
  final int? id;
  final DateTime date;
  final double total;
  final double profit;
  final double paid;
  final List<SaleItem> items;

  const Sale({
    this.id,
    required this.date,
    required this.total,
    required this.profit,
    required this.paid,
    this.items = const [],
  });

  double get change => paid - total;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'date': date.toIso8601String(),
    'total': total,
    'profit': profit,
    'paid': paid,
  };

  factory Sale.fromMap(
    Map<String, Object?> map, {
    List<SaleItem> items = const [],
  }) => Sale(
    id: map['id'] as int?,
    date: DateTime.parse(map['date'] as String),
    total: (map['total'] as num).toDouble(),
    profit: (map['profit'] as num).toDouble(),
    paid: (map['paid'] as num).toDouble(),
    items: items,
  );
}
