import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const expenseCategories = <String>[
  'Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'
];
const incomeCategories = <String>['Salário', 'Freelance', 'Investimentos', 'Outros'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> transactions = <MoneyTransaction>[];
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
    await StorageService.write(
      'finance',
      transactions.map((item) => item.toJson()).toList(),
    );
  }

  bool _inMonth(MoneyTransaction item) {
    return item.date.startsWith(DateFormat('yyyy-MM').format(selectedMonth));
  }

  double _total(Iterable<MoneyTransaction> items) {
    return items.fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> _editTransaction([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(
      text: old == null ? '' : old.amount.toStringAsFixed(2),
    );
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final categories = income ? incomeCategories : expenseCategories;
            if (!categories.contains(category)) category = 'Outros';
            return AlertDialog(
              title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R$ ',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Entrada de dinheiro'),
                      value: income,
                      onChanged: (value) {
                        setDialogState(() => income = value);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: categories
                          .map((item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Categoria'),
                    ),
                  ],
                ),
              ),
              actions: [
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

    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (confirmed != true || description.text.trim().isEmpty || value == null || value <= 0) {
      return;
    }

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
    final monthItems = transactions.where(_inMonth).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final income = _total(monthItems.where((item) => item.income));
    final expense = _total(monthItems.where((item) => !item.income));
    final monthBalance = income - expense;
    final totalIncome = _total(transactions.where((item) => item.income));
    final totalExpense = _total(transactions.where((item) => !item.income));
    final balance = totalIncome - totalExpense;

    final byCategory = <String, double>{};
    for (final item in monthItems.where((item) => !item.income)) {
      byCategory[item.category] = (byCategory[item.category] ?? 0) + item.amount;
    }
    final maxCategory = byCategory.isEmpty
        ? 0.0
        : byCategory.values.reduce((a, b) => a > b ? a : b);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financeiro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${monthItems.length} movimentações em ${DateFormat('MMMM', 'pt_BR').format(selectedMonth)}'),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: _editTransaction,
                icon: const Icon(Icons.add),
                tooltip: 'Nova movimentação',
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _metric('Entradas', income, Icons.arrow_downward),
              _metric('Despesas', expense, Icons.arrow_upward),
            ],
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo atual', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'R$ ${balance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _smallStat('Este mês', monthBalance)),
                    Expanded(child: _smallStat('Entradas totais', totalIncome)),
                    Expanded(child: _smallStat('Despesas totais', totalExpense)),
                  ],
                ),
              ],
            ),
          ),
          if (byCategory.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Despesas por categoria', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...byCategory.entries.map(
                    (entry) => _bar(entry.key, entry.value, maxCategory),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (monthItems.isEmpty)
            const AppCard(child: Text('Nenhuma movimentação neste mês.')),
          ...monthItems.map(
            (item) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(item.income ? Icons.south_west : Icons.north_east)),
                title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${item.category} • ${DateFormat('dd/MM').format(DateTime.parse(item.date))}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editTransaction(item);
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

  Widget _metric(String label, double value, IconData icon) {
    return Expanded(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text('R$ ${value.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _smallStat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('R$ ${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _bar(String label, double value, double total) {
    final progress = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(label)), Text('R$ ${value.toStringAsFixed(2)}')]),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: progress, minHeight: 8),
        ],
      ),
    );
  }
}
