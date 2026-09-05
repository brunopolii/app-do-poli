import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> expenseCategories = <String>[
  'Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'
];
const List<String> incomeCategories = <String>['Salário', 'Freelance', 'Investimentos', 'Outros'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> items = <MoneyTransaction>[];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await StorageService.read('finance');
      items = data.map(MoneyTransaction.fromJson).toList();
    } catch (_) {
      items = <MoneyTransaction>[];
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() => StorageService.write(
    'finance', items.map((e) => e.toJson()).toList(),
  );

  double _sum(Iterable<MoneyTransaction> list, bool income) {
    return list.where((e) => e.income == income).fold<double>(
      0.0, (sum, e) => sum + e.amount,
    );
  }

  Future<void> _edit([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(
      text: old == null ? '' : old.amount.toStringAsFixed(2),
    );
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          final categories = income ? incomeCategories : expenseCategories;
          if (!categories.contains(category)) category = 'Outros';
          return AlertDialog(
            title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                  ),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Entrada'),
                    value: income,
                    onChanged: (value) => setDialog(() {
                      income = value;
                      category = 'Outros';
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    items: categories.map((value) => DropdownMenuItem<String>(
                      value: value, child: Text(value),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) setDialog(() => category = value);
                    },
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
            ],
          );
        },
      ),
    );

    final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (result != true || description.text.trim().isEmpty || value == null || value <= 0) return;

    final transaction = MoneyTransaction(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: old?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      description: description.text.trim(),
      category: category,
      amount: value,
      income: income,
    );
    items.removeWhere((e) => e.id == transaction.id);
    items.add(transaction);
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(MoneyTransaction item) async {
    items.removeWhere((e) => e.id == item.id);
    await _save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM').format(month);
    final current = items.where((e) => e.date.startsWith(key)).toList();
    final income = _sum(current, true);
    final expense = _sum(current, false);
    final balance = _sum(items, true) - _sum(items, false);
    final byCategory = <String, double>{};
    for (final item in current.where((e) => !e.income)) {
      byCategory[item.category] = (byCategory[item.category] ?? 0.0) + item.amount;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text('Financeiro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(onPressed: _edit, icon: const Icon(Icons.add_circle_outline)),
          ]),
          AppCard(child: Row(children: <Widget>[
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(month), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
          ])),
          Row(children: <Widget>[
            Expanded(child: _metric('Entradas', income, Icons.arrow_downward)),
            Expanded(child: _metric('Despesas', expense, Icons.arrow_upward)),
          ]),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('Saldo atual', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('R\$ ${balance.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Resultado do mês: R\$ ${(income - expense).toStringAsFixed(2)}'),
          ])),
          if (byCategory.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('Distribuição das despesas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: <Widget>[
              Expanded(child: DonutChart(values: byCategory)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: byCategory.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('${entry.key}: R\$ ${entry.value.toStringAsFixed(2)}', maxLines: 1, overflow: TextOverflow.ellipsis),
              )).toList())),
            ]),
          ])),
          if (income + expense > 0) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('Entradas x despesas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(height: 180, child: DonutChart(values: <String, double>{'Entradas': income, 'Despesas': expense})),
          ])),
          Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (current.isEmpty) const AppCard(child: Text('Nenhuma movimentação neste mês.')),
          ...current.map((item) => AppCard(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(item.income ? Icons.add : Icons.remove)),
            title: Text(item.description),
            subtitle: Text('${item.category} • ${item.date.split('-').reversed.join('/')}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _edit(item);
                if (value == 'delete') _delete(item);
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                PopupMenuItem<String>(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ))),
        ],
      ),
    );
  }

  Widget _metric(String label, double value, IconData icon) {
    return AppCard(child: Row(children: <Widget>[
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('R\$ ${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label),
      ])),
    ]));
  }
}

class DonutChart extends StatelessWidget {
  final Map<String, double> values;
  const DonutChart({super.key, required this.values});
  @override Widget build(BuildContext context) {
    return CustomPaint(painter: _DonutPainter(values, Theme.of(context).colorScheme.primary), size: const Size(double.infinity, 180));
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, double> values;
  final Color color;
  _DonutPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.values.fold<double>(0.0, (sum, value) => sum + value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.34;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 30;
    double start = -3.14159265359 / 2;
    int index = 0;
    final count = values.length;
    for (final value in values.values) {
      final sweep = 2 * 3.14159265359 * value / total;
      paint.color = Color.lerp(color, Colors.transparent, count <= 1 ? 0.0 : index / count) ?? color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
      index++;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values || oldDelegate.color != color;
}
