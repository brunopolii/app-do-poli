import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> expenseCategories = <String>[
  'Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'
];
const List<String> incomeCategories = <String>[
  'Salário', 'Freelance', 'Investimentos', 'Outros'
];

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

  double _sum(Iterable<MoneyTransaction> values) {
    double total = 0;
    for (final item in values) {
      total += item.amount;
    }
    return total;
  }

  Future<void> _editTransaction([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(
      text: old == null ? '' : old.amount.toStringAsFixed(2),
    );
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categories = income ? incomeCategories : expenseCategories;
            if (!categories.contains(category)) {
              category = 'Outros';
            }

            return AlertDialog(
              title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: description,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixText: 'R$ ',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Entrada de dinheiro'),
                      value: income,
                      onChanged: (value) {
                        setDialogState(() {
                          income = value;
                          category = 'Outros';
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: categories.map((item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
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

    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (saved != true || description.text.trim().isEmpty || value == null || value <= 0) {
      return;
    }

    final transaction = MoneyTransaction(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: old?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      description: description.text.trim(),
      category: category,
      amount: value,
      income: income,
    );

    transactions.removeWhere((item) => item.id == transaction.id);
    transactions.add(transaction);
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(MoneyTransaction transaction) async {
    transactions.removeWhere((item) => item.id == transaction.id);
    await _save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = DateFormat('yyyy-MM').format(selectedMonth);
    final items = transactions.where((item) => item.date.startsWith(monthKey)).toList();
    items.sort((a, b) => b.date.compareTo(a.date));

    final income = _sum(items.where((item) => item.income));
    final expense = _sum(items.where((item) => !item.income));
    final balance = _sum(transactions.where((item) => item.income)) -
        _sum(transactions.where((item) => !item.income));

    final byCategory = <String, double>{};
    for (final item in items) {
      if (!item.income) {
        byCategory[item.category] = (byCategory[item.category] ?? 0) + item.amount;
      }
    }

    double maxCategory = 1;
    for (final value in byCategory.values) {
      if (value > maxCategory) maxCategory = value;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Financeiro',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text('${items.length} movimentações neste mês'),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: _editTransaction,
                icon: const Icon(Icons.add),
                tooltip: 'Adicionar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => setState(() {
                    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
                  }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
                  }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              _metric('Entradas', income, Icons.arrow_downward),
              _metric('Despesas', expense, Icons.arrow_upward),
            ],
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Saldo atual', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'R$ ${balance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text('Resultado do mês: R$ ${(income - expense).toStringAsFixed(2)}'),
              ],
            ),
          ),
          if (byCategory.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Despesas por categoria',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...byCategory.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(child: Text(entry.key)),
                              Text('R$ ${entry.value.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: entry.value / maxCategory,
                            minHeight: 8,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Movimentações',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (items.isEmpty)
            const AppCard(child: Text('Nenhuma movimentação neste mês.'))
          else
            ...items.map((item) {
              return AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(item.income ? Icons.arrow_downward : Icons.arrow_upward),
                  ),
                  title: Text(item.description),
                  subtitle: Text('${item.category} • ${_formatDate(item.date)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editTransaction(item);
                      if (value == 'delete') _delete(item);
                    },
                    itemBuilder: (context) => const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                      PopupMenuItem<String>(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd/MM').format(date);
  }

  Widget _metric(String label, double value, IconData icon) {
    return Expanded(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              'R$ ${value.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
