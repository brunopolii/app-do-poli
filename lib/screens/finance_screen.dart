import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> expenseCategories = <String>['Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'];
const List<String> incomeCategories = <String>['Salário', 'Freelance', 'Investimentos', 'Outros'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> transactions = <MoneyTransaction>[];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await StorageService.read('finance');
    transactions = data.map(MoneyTransaction.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await StorageService.write('finance', transactions.map((e) => e.toJson()).toList());
  }

  double _sum(Iterable<MoneyTransaction> list) {
    double total = 0;
    for (final item in list) total += item.amount;
    return total;
  }

  Future<void> _editor([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(text: old == null ? '' : old.amount.toStringAsFixed(2));
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final categories = income ? incomeCategories : expenseCategories;
          if (!categories.contains(category)) category = 'Outros';
          return AlertDialog(
            title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
              TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R$ ')),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('É uma entrada'), value: income, onChanged: (v) => setDialogState(() => income = v)),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: categories.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
                onChanged: (v) { if (v != null) setDialogState(() => category = v); },
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
            ])),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
            ],
          );
        },
      ),
    );

    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (ok != true || description.text.trim().isEmpty || value == null || value <= 0) return;
    final item = MoneyTransaction(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: old?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      description: description.text.trim(), category: category, amount: value, income: income,
    );
    transactions.removeWhere((e) => e.id == item.id);
    transactions.add(item);
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(MoneyTransaction item) async {
    transactions.removeWhere((e) => e.id == item.id);
    await _save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM').format(month);
    final items = transactions.where((e) => e.date.startsWith(key)).toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    final income = _sum(items.where((e) => e.income));
    final expense = _sum(items.where((e) => !e.income));
    final currentBalance = _sum(transactions.where((e) => e.income)) - _sum(transactions.where((e) => !e.income));

    final categories = <String, double>{};
    for (final item in items) {
      if (!item.income) categories[item.category] = (categories[item.category] ?? 0) + item.amount;
    }
    double maxCategory = 1;
    for (final value in categories.values) { if (value > maxCategory) maxCategory = value; }

    final children = <Widget>[];
    children.add(Row(children: <Widget>[
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('Financeiro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text('${items.length} movimentações neste mês'),
      ])),
      IconButton.filled(onPressed: _editor, icon: const Icon(Icons.add)),
    ]));
    children.add(AppCard(child: Row(children: <Widget>[
      IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
      Expanded(child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
      IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
    ])));
    children.add(Row(children: <Widget>[
      _metric('Entradas', income, Icons.south_west),
      _metric('Despesas', expense, Icons.north_east),
    ]));
    children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('Saldo atual', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('R$ ${currentBalance.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Resultado do mês: R$ ${(income - expense).toStringAsFixed(2)}'),
    ])));

    if (categories.isNotEmpty) {
      final categoryChildren = <Widget>[];
      categoryChildren.add(Text('Despesas por categoria', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)));
      categoryChildren.add(const SizedBox(height: 12));
      for (final entry in categories.entries) {
        categoryChildren.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Expanded(child: Text(entry.key)), Text('R$ ${entry.value.toStringAsFixed(2)}')]),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: entry.value / maxCategory, minHeight: 8),
        ])));
      }
      children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: categoryChildren)));
    }

    children.add(const SizedBox(height: 4));
    children.add(Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)));
    if (items.isEmpty) {
      children.add(const AppCard(child: Text('Nenhuma movimentação neste mês.')));
    } else {
      for (final item in items) {
        children.add(AppCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(item.income ? Icons.arrow_downward : Icons.arrow_upward)),
          title: Text(item.description),
          subtitle: Text('${item.category} • ${DateFormat('dd/MM').format(DateTime.parse(item.date))}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) { if (value == 'edit') _editor(item); if (value == 'delete') _delete(item); },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
              PopupMenuItem<String>(value: 'delete', child: Text('Excluir')),
            ],
          ),
        )));
      }
    }

    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: children));
  }

  Widget _metric(String label, double value, IconData icon) {
    return Expanded(child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Icon(icon),
      const SizedBox(height: 6),
      Text('R$ ${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(label),
    ])));
  }
}
