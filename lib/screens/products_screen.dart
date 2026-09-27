import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/store_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_actions.dart';
import 'scanner_screen.dart';

enum _Filter { all, lowStock, expiring }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  _Filter _filter = _Filter.all;
  String? _category;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _visible(List<Product> products) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return products.where((p) {
      if (_category != null && p.category != _category) return false;
      if (_filter == _Filter.lowStock && !p.isLowStock) return false;
      if (_filter == _Filter.expiring && !p.isExpiringWithin(7)) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.barcode.contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _scanSearch() async {
    final code = await scanBarcode(context, title: 'البحث بالباركود');
    if (code == null || !mounted) return;
    final product = await context.read<StoreProvider>().findByBarcode(code);
    if (!mounted) return;
    if (product != null) {
      await showProductSheet(context, product);
    } else {
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('منتج غير مسجل'),
          content: Text('الباركود $code غير موجود. هل تريد إضافة منتج جديد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لا'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة'),
            ),
          ],
        ),
      );
      if (add == true && mounted) {
        await openProductForm(context, barcode: code);
      }
    }
  }

  Future<void> _delete(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${product.name}" نهائيا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<StoreProvider>().deleteProduct(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    final products = _visible(store.products);
    final categories = store.categories;

    return Scaffold(
      appBar: AppBar(
        title: Text('المنتجات (${store.products.length})'),
        actions: [
          IconButton(
            tooltip: 'إدخال سلع بالباركود',
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () => receiveStockByScan(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم، الباركود أو الصنف',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: 'بحث بالكاميرا',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanSearch,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(switch (f) {
                        _Filter.all => 'الكل',
                        _Filter.lowStock => 'مخزون ناقص',
                        _Filter.expiring => 'صلاحية قريبة',
                      }),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
                if (categories.length > 1) ...[
                  const VerticalDivider(),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: FilterChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (s) =>
                            setState(() => _category = s ? c : null),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: store.refresh,
              child: products.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('لا توجد منتجات')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          _productTile(context, products[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(BuildContext context, Product p) {
    final stockColor = p.isOutOfStock
        ? Colors.red
        : p.isLowStock
        ? Colors.orange
        : Colors.green;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: stockColor.withValues(alpha: 0.15),
        child: Icon(Icons.inventory_2, color: stockColor),
      ),
      title: Text(p.name),
      subtitle: Text(
        [
          p.barcode,
          p.category,
          if (p.expiryDate != null) 'صلاحية: ${formatDate(p.expiryDate!)}',
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(p.salePrice),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${formatQty(p.quantity)} ${p.unit}',
            style: TextStyle(color: stockColor),
          ),
        ],
      ),
      onTap: () => showProductSheet(context, p),
      onLongPress: () => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('تعديل'),
                onTap: () {
                  Navigator.pop(ctx);
                  openProductForm(context, product: p);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_box),
                title: const Text('إدخال مخزون'),
                onTap: () {
                  Navigator.pop(ctx);
                  receiveStock(context, p);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف'),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete(p);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
