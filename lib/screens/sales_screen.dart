import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store_database.dart';
import '../models/sale.dart';
import '../providers/store_provider.dart';
import '../utils/formatters.dart';

enum _Period { today, week, month, all }

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  _Period _period = _Period.today;
  Future<List<Sale>>? _future;
  StoreProvider? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = context.read<StoreProvider>();
    if (_store != store) {
      _store?.removeListener(_load);
      _store = store..addListener(_load);
      _future = _query();
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_load);
    super.dispose();
  }

  void _load() {
    if (!mounted || _store!.loading) return;
    setState(() {
      _future = _query();
    });
  }

  Future<List<Sale>> _query() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = switch (_period) {
      _Period.today => today,
      _Period.week => today.subtract(const Duration(days: 6)),
      _Period.month => DateTime(now.year, now.month, 1),
      _Period.all => null,
    };
    return context.read<StoreDatabase>().getSales(from: from);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل المبيعات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.today, label: Text('اليوم')),
                ButtonSegment(value: _Period.week, label: Text('7 أيام')),
                ButtonSegment(value: _Period.month, label: Text('الشهر')),
                ButtonSegment(value: _Period.all, label: Text('الكل')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() {
                _period = s.first;
                _future = _query();
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sales = snap.data!;
                final total = sales.fold<double>(0, (s, e) => s + e.total);
                final profit = sales.fold<double>(0, (s, e) => s + e.profit);
                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summary('العمليات', '${sales.length}'),
                            _summary('المبيعات', formatMoney(total)),
                            _summary('الربح', formatMoney(profit)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: sales.isEmpty
                          ? const Center(child: Text('لا توجد مبيعات'))
                          : ListView.separated(
                              itemCount: sales.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final sale = sales[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      '${sale.id}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  title: Text(formatMoney(sale.total)),
                                  subtitle: Text(formatDateTime(sale.date)),
                                  trailing: Text(
                                    '+${formatMoney(sale.profit)}',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SaleDetailsScreen(sale: sale),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(String label, String value) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

class SaleDetailsScreen extends StatelessWidget {
  final Sale sale;

  const SaleDetailsScreen({super.key, required this.sale});

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء البيع'),
        content: const Text(
          'سيتم حذف عملية البيع وإرجاع المنتجات إلى المخزون. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final store = context.read<StoreProvider>();
    await context.read<StoreDatabase>().deleteSale(sale.id!);
    await store.refresh();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('البيع رقم ${sale.id}'),
        actions: [
          IconButton(
            tooltip: 'إلغاء البيع',
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _cancel(context),
          ),
        ],
      ),
      body: FutureBuilder<List<SaleItem>>(
        future: context.read<StoreDatabase>().getSaleItems(sale.id!),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                formatDateTime(sale.date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Divider(),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text(
                    '${formatQty(item.quantity)} × ${formatMoney(item.unitPrice)}',
                  ),
                  trailing: Text(
                    formatMoney(item.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const Divider(),
              _line(context, 'المجموع', formatMoney(sale.total), bold: true),
              _line(context, 'المدفوع', formatMoney(sale.paid)),
              _line(context, 'الباقي', formatMoney(sale.change)),
              _line(context, 'الربح', formatMoney(sale.profit)),
            ],
          );
        },
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : null,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}
