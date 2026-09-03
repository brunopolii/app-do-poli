import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const expenseCategories = <String>['Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'];
const incomeCategories = <String>['Salário', 'Freelance', 'Investimentos', 'Outros'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> transactions = [];
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await StorageService.read('finance');
    transactions = data.map(MoneyTransaction.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await StorageService.write('finance', transactions.map((e) => e.toJson()).toList());
  }

  bool _isMonth(MoneyTransaction item) {
    return item.date.startsWith(DateFormat('yyyy-MM').format(selectedMonth));
  }

  double _sum(Iterable<MoneyTransaction> items) {
    return items.fold(0.0, (total, item) => total + item.amount);
  }

  Future<void> _addOrEdit([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(text: old == null ? '' : old.amount.toString());
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categories = income ? incomeCategories : expenseCategories;
            if (!categories.contains(category)) category = 'Outros';
            return AlertDialog(
              title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
                    TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R$ ')),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Entrada de dinheiro'),
                      value: income,
                      onChanged: (value) => setDialogState(() => income = value),
                    ),
                    DropdownButtonFormField<String>(
                      value: category,
                      items: categories.map((item) => DropdownMenuItem<String>(value: item, child: Text(item))).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => category = value);
                      },
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
              ],
            );
          },
        );
      },
    );

    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (result != true || description.text.trim().isEmpty || value == null || value <= 0) return;

    final item = MoneyTransaction(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: old?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      description: description.text.trim(),
      category: category,
      amount: value,
      income: income,
    );
    transactions.removeWhere((entry) => entry.id == item.id);
    transactions.add(item);
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(MoneyTransaction item) async {
    transactions.removeWhere((entry) => entry.id == item.id);
    await _save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final monthItems = transactions.where(_isMonth).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final income = _sum(monthItems.where((item) => item.income));
    final expense = _sum(monthItems.where((item) => !item.income));
    final result = income - expense;
    final balance = _sum(transactions.where((item) => item.income)) - _sum(transactions.where((item) => !item.income));

    final categories = <String, double>{};
    for (final item in monthItems.where((item) => !item.income)) {
      categories[item.category] = (categories[item.category] ?? 0) + item.amount;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Financeiro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('${monthItems.length} movimentações neste mês'),
                ]),
              ),
              IconButton.filled(onPressed: _addOrEdit, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                IconButton(onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
                Expanded(child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Row(children: [_metric('Entradas', income), _metric('Despesas', expense), _metric('Saldo', result)]),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Visão geral', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _bar('Entradas', income, income + expense),
              _bar('Despesas', expense, income + expense),
              const SizedBox(height: 4),
              Text('Saldo acumulado: R$ ${balance.toStringAsFixed(2)}'),
            ]),
          ),
          if (categories.isNotEmpty)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Despesas por categoria', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...categories.entries.map((entry) => _bar(entry.key, entry.value, categories.values.reduce((a, b) => a > b ? a : b))),
              ]),
            ),
          const SizedBox(height: 8),
          Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (monthItems.isEmpty) const AppCard(child: Text('Nenhuma movimentação neste mês.')),
          ...monthItems.map(
            (item) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(item.income ? Icons.arrow_downward : Icons.arrow_upward)),
                title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${item.category} • ${DateFormat('dd/MM').format(DateTime.parse(item.date))}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _addOrEdit(item);
                    if (value == 'delete') _delete(item);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, double value) {
    return Expanded(
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('R$ ${value.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }

  Widget _bar(String label, double value, double total) {
    final progress = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label)), Text('R$ ${value.toStringAsFixed(2)}')]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: progress, minHeight: 8),
      ]),
    );
  }
}
