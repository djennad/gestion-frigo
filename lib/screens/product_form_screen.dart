import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_database.dart';
import '../models/product.dart';
import '../providers/store_provider.dart';
import '../utils/barcode_utils.dart';
import '../utils/formatters.dart';
import 'scanner_screen.dart';

const productUnits = [
  'قطعة',
  'كغ',
  'غ',
  'لتر',
  'علبة',
  'كيس',
  'قارورة',
  'رزمة',
];

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;

  const ProductFormScreen({super.key, this.product, this.initialBarcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _purchase;
  late final TextEditingController _sale;
  late final TextEditingController _quantity;
  late final TextEditingController _minQuantity;
  final _categoryFocus = FocusNode();
  late String _unit;
  DateTime? _expiry;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    String num(double? v) => v == null ? '' : formatQty(v).replaceAll(',', '');
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(
      text: p?.barcode ?? widget.initialBarcode ?? '',
    );
    _category = TextEditingController(text: p?.category ?? 'عام');
    _purchase = TextEditingController(text: num(p?.purchasePrice));
    _sale = TextEditingController(text: num(p?.salePrice));
    _quantity = TextEditingController(text: num(p?.quantity ?? 0));
    _minQuantity = TextEditingController(text: num(p?.minQuantity ?? 5));
    _unit = p?.unit ?? productUnits.first;
    if (!productUnits.contains(_unit)) _unit = productUnits.first;
    _expiry = p?.expiryDate;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _barcode,
      _category,
      _purchase,
      _sale,
      _quantity,
      _minQuantity,
    ]) {
      c.dispose();
    }
    _categoryFocus.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code != null) setState(() => _barcode.text = code);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'حقل إجباري' : null;

  String? _number(String? v) {
    final n = parseNumber(v);
    if (n == null) return 'أدخل رقما صحيحا';
    if (n < 0) return 'لا يمكن أن يكون سالبا';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      barcode: _barcode.text.trim(),
      category: _category.text.trim().isEmpty ? 'عام' : _category.text.trim(),
      unit: _unit,
      purchasePrice: parseNumber(_purchase.text)!,
      salePrice: parseNumber(_sale.text)!,
      quantity: parseNumber(_quantity.text)!,
      minQuantity: parseNumber(_minQuantity.text)!,
      expiryDate: _expiry,
    );
    if (product.salePrice < product.purchasePrice) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه'),
          content: const Text('سعر البيع أقل من سعر الشراء. هل تريد المتابعة؟'),
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
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await context.read<StoreProvider>().saveProduct(product);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DuplicateBarcodeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<StoreProvider>().categories;
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل منتج' : 'منتج جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'الباركود',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'توليد باركود داخلي',
                      icon: const Icon(Icons.auto_fix_high),
                      onPressed: () => setState(
                        () => _barcode.text = generateInternalBarcode(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'مسح بالكاميرا',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scan,
                    ),
                  ],
                ),
              ),
              validator: _required,
            ),
            gap,
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج',
                prefixIcon: Icon(Icons.label),
              ),
              validator: _required,
            ),
            gap,
            Autocomplete<String>(
              textEditingController: _category,
              focusNode: _categoryFocus,
              optionsBuilder: (value) => categories.where(
                (c) => c.contains(value.text) && c != value.text,
              ),
              fieldViewBuilder: (context, ctrl, focus, onSubmit) =>
                  TextFormField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      labelText: 'الصنف (حليب، مصبرات، مشروبات...)',
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
            ),
            gap,
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(
                labelText: 'الوحدة',
                prefixIcon: Icon(Icons.straighten),
              ),
              items: productUnits
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchase,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'سعر الشراء',
                      suffixText: 'دج',
                    ),
                    validator: _number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sale,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'سعر البيع',
                      suffixText: 'دج',
                    ),
                    validator: _number,
                  ),
                ),
              ],
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الكمية في المخزون',
                    ),
                    validator: _number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minQuantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'حد التنبيه'),
                    validator: _number,
                  ),
                ),
              ],
            ),
            gap,
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.event),
              title: const Text('تاريخ انتهاء الصلاحية'),
              subtitle: Text(
                _expiry == null ? 'غير محدد' : formatDate(_expiry!),
              ),
              trailing: _expiry == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiry = null),
                    ),
              onTap: _pickExpiry,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
