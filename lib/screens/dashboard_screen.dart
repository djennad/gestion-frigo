import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/store_provider.dart';
import '../utils/formatters.dart';
import '../widgets/product_actions.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    final stats = store.stats;
    final lowStock = store.lowStockProducts;
    final expiring = store.expiringProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسيير المحل'),
        actions: [
          IconButton(
            tooltip: 'التحقق من السعر',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => scanAndShowProduct(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _StatCard(
                  icon: Icons.payments,
                  label: 'مبيعات اليوم',
                  value: formatMoney(stats.todaySales),
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.trending_up,
                  label: 'ربح اليوم',
                  value: formatMoney(stats.todayProfit),
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.receipt,
                  label: 'عدد العمليات',
                  value: '${stats.todayCount}',
                  color: Colors.purple,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.warehouse,
                  label: 'قيمة المخزون',
                  value: formatMoney(stats.stockValue),
                  color: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'عمليات سريعة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: [
                _ActionButton(
                  icon: Icons.point_of_sale,
                  label: 'بيع جديد',
                  onTap: () => onNavigate(1),
                ),
                _ActionButton(
                  icon: Icons.add_shopping_cart,
                  label: 'إدخال سلع',
                  onTap: () => receiveStockByScan(context),
                ),
                _ActionButton(
                  icon: Icons.add_box,
                  label: 'منتج جديد',
                  onTap: () => openProductForm(context),
                ),
                _ActionButton(
                  icon: Icons.price_check,
                  label: 'التحقق من السعر',
                  onTap: () => scanAndShowProduct(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _AlertSection(
              title: 'مخزون ناقص (${lowStock.length})',
              icon: Icons.warning_amber,
              color: Colors.red,
              emptyText: 'لا توجد منتجات ناقصة',
              children: lowStock
                  .take(10)
                  .map(
                    (p) => ListTile(
                      dense: true,
                      title: Text(p.name),
                      subtitle: Text(p.barcode),
                      trailing: Text(
                        '${formatQty(p.quantity)} ${p.unit}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => showProductSheet(context, p),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _AlertSection(
              title: 'صلاحية قريبة الانتهاء (${expiring.length})',
              icon: Icons.event_busy,
              color: Colors.orange,
              emptyText: 'لا توجد منتجات قريبة من انتهاء الصلاحية',
              children: expiring
                  .take(10)
                  .map(
                    (p) => ListTile(
                      dense: true,
                      title: Text(p.name),
                      subtitle: Text(
                        p.isExpired() ? 'منتهية الصلاحية' : 'تنتهي قريبا',
                      ),
                      trailing: Text(
                        formatDate(p.expiryDate!),
                        style: TextStyle(
                          color: p.isExpired() ? Colors.red : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => showProductSheet(context, p),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              FittedBox(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _AlertSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String emptyText;
  final List<Widget> children;

  const _AlertSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(emptyText),
            )
          else
            ...children,
        ],
      ),
    );
  }
}
