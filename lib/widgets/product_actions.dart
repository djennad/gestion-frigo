import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/store_provider.dart';
import '../screens/product_form_screen.dart';
import '../screens/scanner_screen.dart';
import '../utils/formatters.dart';

Future<bool?> openProductForm(
  BuildContext context, {
  Product? product,
  String? barcode,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          ProductFormScreen(product: product, initialBarcode: barcode),
    ),
  );
}

/// Asks the user for a positive quantity.
Future<double?> askQuantity(
  BuildContext context, {
  required String title,
  String? hint,
  double? initial,
}) {
  final ctrl = TextEditingController(
    text: initial == null ? '' : formatQty(initial).replaceAll(',', ''),
  );
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = parseNumber(ctrl.text);
        if (v != null && v > 0) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'الكمية', helperText: hint),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(onPressed: submit, child: const Text('تأكيد')),
        ],
      );
    },
  );
}

Future<void> receiveStock(BuildContext context, Product product) async {
  final qty = await askQuantity(
    context,
    title: 'إدخال مخزون: ${product.name}',
    hint: 'المخزون الحالي: ${formatQty(product.quantity)} ${product.unit}',
  );
  if (qty == null || !context.mounted) return;
  await context.read<StoreProvider>().adjustStock(product, qty);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'تمت إضافة ${formatQty(qty)} ${product.unit} إلى ${product.name}',
      ),
    ),
  );
}

/// Continuous scanning session to receive goods from a supplier.
Future<void> receiveStockByScan(BuildContext context) {
  final store = context.read<StoreProvider>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (scannerContext) => ScannerScreen(
        title: 'إدخال السلع بالباركود',
        onScan: (code) async {
          final product = await store.findByBarcode(code);
          if (!scannerContext.mounted) return null;
          if (product == null) {
            final add = await showDialog<bool>(
              context: scannerContext,
              builder: (ctx) => AlertDialog(
                title: const Text('منتج غير مسجل'),
                content: Text('الباركود $code غير موجود. هل تريد إضافته؟'),
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
            if (add == true && scannerContext.mounted) {
              final saved = await openProductForm(
                scannerContext,
                barcode: code,
              );
              return saved == true ? 'تمت إضافة المنتج الجديد' : 'تم الإلغاء';
            }
            return 'باركود غير مسجل: $code';
          }
          final qty = await askQuantity(
            scannerContext,
            title: product.name,
            hint:
                'المخزون الحالي: ${formatQty(product.quantity)} ${product.unit}',
          );
          if (qty == null) return 'تم الإلغاء';
          await store.adjustStock(product, qty);
          return '+${formatQty(qty)} ${product.unit} ${product.name}';
        },
      ),
    ),
  );
}

/// Scans a code and shows the matching product (price check).
Future<void> scanAndShowProduct(BuildContext context) async {
  final code = await scanBarcode(context, title: 'التحقق من السعر');
  if (code == null || !context.mounted) return;
  final product = await context.read<StoreProvider>().findByBarcode(code);
  if (!context.mounted) return;
  if (product == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('الباركود $code غير مسجل'),
        action: SnackBarAction(
          label: 'إضافة',
          onPressed: () => openProductForm(context, barcode: code),
        ),
      ),
    );
    return;
  }
  await showProductSheet(context, product);
}

Future<void> showProductSheet(BuildContext context, Product product) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(product.name, style: theme.textTheme.headlineSmall),
            Text(product.barcode, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              formatMoney(product.salePrice),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(),
            row('الصنف', product.category),
            row('سعر الشراء', formatMoney(product.purchasePrice)),
            row('الربح للوحدة', formatMoney(product.margin)),
            row(
              'المخزون',
              '${formatQty(product.quantity)} ${product.unit}',
              color: product.isLowStock ? Colors.red : null,
            ),
            if (product.expiryDate != null)
              row(
                'انتهاء الصلاحية',
                formatDate(product.expiryDate!),
                color: product.isExpiringWithin(7) ? Colors.orange : null,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('تعديل'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      openProductForm(context, product: product);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_box),
                    label: const Text('إدخال مخزون'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      receiveStock(context, product);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
