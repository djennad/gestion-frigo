import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_database.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_actions.dart';
import 'scanner_screen.dart';

/// Checkout screen: scan (camera or USB/Bluetooth scanner) or search products,
/// then cash in.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  String _addProduct(Product product) {
    if (product.isOutOfStock) return 'نفد المخزون: ${product.name}';
    final ok = context.read<CartProvider>().add(product);
    return ok
        ? '${product.name} — ${formatMoney(product.salePrice)}'
        : 'الكمية غير كافية: ${product.name} (${formatQty(product.quantity)})';
  }

  /// Looks up [code] and adds it to the cart. Returns a status message.
  Future<String> _addByBarcode(String code) async {
    final product = await context.read<StoreProvider>().findByBarcode(code);
    if (!mounted) return '';
    if (product == null) return 'باركود غير مسجل: $code';
    return _addProduct(product);
  }

  Future<void> _submitCode(String value) async {
    final code = value.trim();
    _codeCtrl.clear();
    if (code.isEmpty) return;
    final product = await context.read<StoreProvider>().findByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('باركود غير مسجل: $code'),
          action: SnackBarAction(
            label: 'إضافة',
            onPressed: () => openProductForm(context, barcode: code),
          ),
        ),
      );
    } else {
      _snack(_addProduct(product));
    }
    _codeFocus.requestFocus();
  }

  Future<void> _scanWithCamera() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ScannerScreen(title: 'البيع بالباركود', onScan: _addByBarcode),
      ),
    );
  }

  Future<void> _searchProduct() async {
    final products = context.read<StoreProvider>().products;
    final product = await showSearch<Product?>(
      context: context,
      delegate: _ProductSearchDelegate(products),
    );
    if (product != null && mounted) _snack(_addProduct(product));
  }

  Future<void> _editQuantity(CartItem item) async {
    final qty = await askQuantity(
      context,
      title: item.product.name,
      initial: item.quantity,
      hint: 'المتوفر: ${formatQty(item.product.quantity)} ${item.product.unit}',
    );
    if (qty == null || !mounted) return;
    if (!context.read<CartProvider>().setQuantity(item, qty)) {
      _snack('الكمية غير كافية في المخزون');
    }
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    final paid = await showDialog<double>(
      context: context,
      builder: (_) => _PaymentDialog(total: cart.total),
    );
    if (paid == null || !mounted) return;
    final db = context.read<StoreDatabase>();
    final store = context.read<StoreProvider>();
    try {
      final sale = await cart.checkout(db, paid: paid);
      await store.refresh();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _ReceiptDialog(sale: sale),
      );
    } on InsufficientStockException catch (e) {
      if (mounted) _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('البيع'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'إفراغ السلة',
              icon: const Icon(Icons.remove_shopping_cart),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('إفراغ السلة؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('لا'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('نعم'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  context.read<CartProvider>().clear();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeCtrl,
                    focusNode: _codeFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'الباركود (قارئ خارجي أو إدخال يدوي)',
                      prefixIcon: Icon(Icons.qr_code),
                      isDense: true,
                    ),
                    onSubmitted: _submitCode,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'بحث بالاسم',
                  icon: const Icon(Icons.search),
                  onPressed: _searchProduct,
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  tooltip: 'مسح بالكاميرا',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanWithCamera,
                ),
              ],
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 72,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text('السلة فارغة — امسح باركود منتج للبدء'),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = cart.items[i];
                      return Dismissible(
                        key: ValueKey(item.product.id),
                        background: Container(color: Colors.red),
                        onDismissed: (_) =>
                            context.read<CartProvider>().remove(item),
                        child: ListTile(
                          title: Text(item.product.name),
                          subtitle: Text(
                            '${formatMoney(item.product.salePrice)} × ${formatQty(item.quantity)} ${item.product.unit}',
                          ),
                          onTap: () => _editQuantity(item),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => context
                                    .read<CartProvider>()
                                    .setQuantity(item, item.quantity - 1),
                              ),
                              Text(
                                formatMoney(item.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  if (!context.read<CartProvider>().setQuantity(
                                    item,
                                    item.quantity + 1,
                                  )) {
                                    _snack('الكمية غير كافية في المخزون');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('المجموع (${formatQty(cart.itemCount)} وحدة)'),
                        Text(
                          formatMoney(cart.total),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: cart.isEmpty ? null : _checkout,
                    icon: const Icon(Icons.check),
                    label: const Text('تأكيد البيع'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final double total;

  const _PaymentDialog({required this.total});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _paid;

  @override
  void initState() {
    super.initState();
    _paid = TextEditingController(text: widget.total.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = parseNumber(_paid.text) ?? 0;
    final change = paid - widget.total;
    final valid = paid >= widget.total;
    return AlertDialog(
      title: const Text('الدفع'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'المبلغ المطلوب: ${formatMoney(widget.total)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paid,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المدفوع',
              suffixText: 'دج',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            valid ? 'الباقي: ${formatMoney(change)}' : 'المبلغ غير كاف',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valid ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, paid) : null,
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}

class _ReceiptDialog extends StatelessWidget {
  final Sale sale;

  const _ReceiptDialog({required this.sale});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
      title: Text('تم البيع رقم ${sale.id}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatDateTime(sale.date)),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: sale.items
                    .map(
                      (i) => Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i.productName} × ${formatQty(i.quantity)}',
                            ),
                          ),
                          Text(formatMoney(i.total)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(),
            _line('المجموع', formatMoney(sale.total), bold: true),
            _line('المدفوع', formatMoney(sale.paid)),
            _line('الباقي', formatMoney(sale.change)),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسنا'),
        ),
      ],
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
    ],
  );
}

class _ProductSearchDelegate extends SearchDelegate<Product?> {
  final List<Product> products;

  _ProductSearchDelegate(this.products)
    : super(searchFieldLabel: 'ابحث باسم المنتج أو الباركود');

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const BackButtonIcon(),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim().toLowerCase();
    final results = products
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.barcode.contains(q),
        )
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final p = results[i];
        return ListTile(
          enabled: !p.isOutOfStock,
          title: Text(p.name),
          subtitle: Text('${p.barcode} • المخزون: ${formatQty(p.quantity)}'),
          trailing: Text(formatMoney(p.salePrice)),
          onTap: () => close(context, p),
        );
      },
    );
  }
}
