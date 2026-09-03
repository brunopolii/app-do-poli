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

  Future<void> _save() {
    return StorageService.write('finance', transactions.map((e) => e.toJson()).toList());
  }

  double _sum(Iterable<MoneyTransaction> items) {
    return items.fold<double>(0, (sum, item) => sum + item.amount);
  }

  Future<void> _showEditor([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amountController = TextEditingController(text: old == null ? '' : old.amount.toStringAsFixed(2));
    bool isIncome = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categories = isIncome ? incomeCategories : expenseCategories;
            if (!categories.contains(category)) category = 'Outros';
            return AlertDialog(
              title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R$ '),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('É uma entrada'),
                      value: isIncome,
                      onChanged: (value) => setDialogState(() => isIncome = value),
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

    final value = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (confirmed != true || description.text.trim().isEmpty || value == null || value <= 0) return;

    final item = MoneyTransaction(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: old?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      description: description.text.trim(),
      category: category,
      amount: value,
      income: isIncome,
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
    final monthKey = DateFormat('yyyy-MM').format(selectedMonth);
    final monthItems = transactions.where((item) => item.date.startsWith(monthKey)).toList();
    monthItems.sort((a, b) => b.date.compareTo(a.date));
    final income = _sum(monthItems.where((item) => item.income));
    final expenses = _sum(monthItems.where((item) => !item.income));
    final balance = _sum(transactions.where((item) => item.income)) - _sum(transactions.where((item) => !item.income));

    final categories = <String, double>{};
    for (final item in monthItems.where((item) => !item.income)) {
      categories[item.category] = (categories[item.category] ?? 0) + item.amount;
    }
    final maxCategory = categories.isEmpty ? 1.0 : categories.values.reduce((a, b) => a > b ? a : b);

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
                    Text('${monthItems.length} movimentações neste mês'),
                  ],
                ),
              ),
              IconButton.filled(onPressed: _showEditor, icon: const Icon(Icons.add)),
            ],
          ),
          AppCard(
            child: Row(
              children: [
                IconButton(onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
                Expanded(child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Row(children: [_metric('Entradas', income, Icons.south_west), _metric('Despesas', expenses, Icons.north_east)]),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Saldo atual', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('R$ ${balance.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Resultado do mês: R$ ${(income - expenses).toStringAsFixed(2)}'),
            ]),
          ),
          if (categories.isNotEmpty)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Despesas por categoria', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...categories.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(entry.key)), Text('R$ ${entry.value.toStringAsFixed(2)}')]),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(value: entry.value / maxCategory, minHeight: 8),
                    ]),
                  );
                }),
              ]),
            ),
          const SizedBox(height: 4),
          Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          if (monthItems.isEmpty) const AppCard(child: Text('Nenhuma movimentação neste mês.')),
          ...monthItems.map((item) {
            return AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(item.income ? Icons.arrow_downward : Icons.arrow_upward)),
                title: Text(item.description),
                subtitle: Text('${item.category} • ${DateFormat('dd/MM').format(DateTime.parse(item.date))}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _showEditor(item);
                    if (value == 'delete') _delete(item);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _metric(String label, double value, IconData icon) {
    return Expanded(
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon),
          const SizedBox(height: 6),
          Text('R$ ${value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label),
        ]),
      ),
    );
  }
}
