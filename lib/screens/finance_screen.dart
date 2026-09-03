import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> _expenseCategories = <String>[
  'Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'
];
const List<String> _incomeCategories = <String>[
  'Salário', 'Freelance', 'Investimentos', 'Outros'
];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> transactions = <MoneyTransaction>[];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await StorageService.read('finance');
    final loaded = <MoneyTransaction>[];
    for (final item in data) {
      loaded.add(MoneyTransaction.fromJson(item));
    }
    if (mounted) setState(() => transactions = loaded);
  }

  Future<void> _save() async {
    await StorageService.write(
      'finance',
      transactions.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> _openEditor([MoneyTransaction? old]) async {
    final descriptionController = TextEditingController(text: old?.description ?? '');
    final amountController = TextEditingController(
      text: old == null ? '' : old.amount.toStringAsFixed(2),
    );
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final categories = income ? _incomeCategories : _expenseCategories;
            if (!categories.contains(category)) category = 'Outros';
            return AlertDialog(
              title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R$ '),
                    ),
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
                      items: categories.map((item) {
                        return DropdownMenuItem<String>(value: item, child: Text(item));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => category = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    final parsed = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
    if (result != true || descriptionController.text.trim().isEmpty || parsed == null || parsed <= 0) {
      return;
    }

    final item = MoneyTransaction(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: old?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      description: descriptionController.text.trim(),
      category: category,
      amount: parsed,
      income: income,
    );

    transactions.removeWhere((entry) => entry.id == item.id);
    transactions.add(item);
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _remove(MoneyTransaction item) async {
    transactions.removeWhere((entry) => entry.id == item.id);
    await _save();
    if (mounted) setState(() {});
  }

  double _sum(Iterable<MoneyTransaction> values, bool income) {
    double total = 0;
    for (final item in values) {
      if (item.income == income) total += item.amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = DateFormat('yyyy-MM').format(month);
    final items = transactions.where((item) => item.date.startsWith(monthKey)).toList();
    items.sort((a, b) => b.date.compareTo(a.date));
    final income = _sum(items, true);
    final expense = _sum(items, false);
    final balance = _sum(transactions, true) - _sum(transactions, false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Financeiro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filled(onPressed: _openEditor, icon: const Icon(Icons.add)),
            ],
          ),
          AppCard(
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'pt_BR').format(month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(child: _metric('Entradas', income, Icons.arrow_downward)),
              Expanded(child: _metric('Despesas', expense, Icons.arrow_upward)),
            ],
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Saldo atual', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('R$ ${balance.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('Resultado do mês: R$ ${(income - expense).toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          if (items.isEmpty)
            const AppCard(child: Text('Nenhuma movimentação neste mês.'))
          else
            ...items.map((item) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(item.income ? Icons.add : Icons.remove)),
                title: Text(item.description),
                subtitle: Text('${item.category} • ${_date(item.date)}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _openEditor(item);
                    if (value == 'delete') _remove(item);
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ),
            )),
        ],
      ),
    );
  }

  Widget _metric(String label, double value, IconData icon) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon),
          const SizedBox(height: 6),
          Text('R$ ${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label),
        ],
      ),
    );
  }

  String _date(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM').format(date);
  }
}
