class Product {
  final int? id;
  final String name;
  final String barcode;
  final String category;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final double quantity;
  final double minQuantity;
  final DateTime? expiryDate;

  const Product({
    this.id,
    required this.name,
    required this.barcode,
    this.category = 'عام',
    this.unit = 'قطعة',
    required this.purchasePrice,
    required this.salePrice,
    this.quantity = 0,
    this.minQuantity = 5,
    this.expiryDate,
  });

  double get margin => salePrice - purchasePrice;

  bool get isLowStock => quantity <= minQuantity;

  bool get isOutOfStock => quantity <= 0;

  /// Expired or expiring within [days] days.
  bool isExpiringWithin(int days, {DateTime? now}) {
    if (expiryDate == null) return false;
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    return expiryDate!.isBefore(today.add(Duration(days: days)));
  }

  bool isExpired({DateTime? now}) {
    if (expiryDate == null) return false;
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    return expiryDate!.isBefore(today);
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    String? category,
    String? unit,
    double? purchasePrice,
    double? salePrice,
    double? quantity,
    double? minQuantity,
    DateTime? expiryDate,
    bool clearExpiry = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'barcode': barcode,
    'category': category,
    'unit': unit,
    'purchase_price': purchasePrice,
    'sale_price': salePrice,
    'quantity': quantity,
    'min_quantity': minQuantity,
    'expiry_date': expiryDate?.toIso8601String(),
  };

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id'] as int?,
    name: map['name'] as String,
    barcode: map['barcode'] as String,
    category: (map['category'] as String?) ?? 'عام',
    unit: (map['unit'] as String?) ?? 'قطعة',
    purchasePrice: (map['purchase_price'] as num).toDouble(),
    salePrice: (map['sale_price'] as num).toDouble(),
    quantity: (map['quantity'] as num).toDouble(),
    minQuantity: (map['min_quantity'] as num).toDouble(),
    expiryDate: map['expiry_date'] == null
        ? null
        : DateTime.parse(map['expiry_date'] as String),
  );
}
