import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> _expenses = <String>['Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'];
const List<String> _incomes = <String>['Salário', 'Freelance', 'Investimentos', 'Outros'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
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
    final data = await StorageService.read('finance');
    final result = <MoneyTransaction>[];
    for (final map in data) {
      result.add(MoneyTransaction.fromJson(map));
    }
    if (!mounted) return;
    setState(() => items = result);
  }

  Future<void> _save() async {
    await StorageService.write('finance', items.map((e) => e.toJson()).toList());
  }

  double _sum(Iterable<MoneyTransaction> list, bool income) {
    double total = 0;
    for (final item in list) {
      if (item.income == income) total += item.amount;
    }
    return total;
  }

  Future<void> _edit([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(text: old == null ? '' : old.amount.toStringAsFixed(2));
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categories = income ? _incomes : _expenses;
            if (!categories.contains(category)) category = 'Outros';
            return AlertDialog(
              title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
                    TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R$ ')),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Entrada'),
                      value: income,
                      onChanged: (value) {
                        setDialogState(() {
                          income = value;
                          category = 'Outros';
                        });
                      },
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: category,
                      items: categories.map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => category = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Salvar')),
              ],
            );
          },
        );
      },
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
    current.sort((a, b) => b.date.compareTo(a.date));
    final income = _sum(current, true);
    final expense = _sum(current, false);
    final balance = _sum(items, true) - _sum(items, false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text('Financeiro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add_circle)),
          ]),
          AppCard(child: Row(children: <Widget>[
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(month), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
          ])),
          Row(children: <Widget>[
            Expanded(child: _metric('Entradas', income)),
            Expanded(child: _metric('Despesas', expense)),
          ]),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('Saldo atual', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('R$ ${balance.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text('Resultado do mês: R$ ${(income - expense).toStringAsFixed(2)}'),
          ])),
          const SizedBox(height: 8),
          Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (current.isEmpty) const AppCard(child: Text('Nenhuma movimentação neste mês.')),
          for (final item in current)
            AppCard(child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(item.income ? Icons.add : Icons.remove)),
              title: Text(item.description),
              subtitle: Text('${item.category} • ${item.date.split('-').reversed.join('/')}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _edit(item);
                  if (value == 'delete') _delete(item);
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                  PopupMenuItem<String>(value: 'delete', child: Text('Excluir')),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _metric(String label, double value) {
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('R$ ${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(label),
    ]));
  }
}
