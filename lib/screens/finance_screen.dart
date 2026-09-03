import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> expenseCategories = <String>[
  'Alimentação',
  'Transporte',
  'Moradia',
  'Lazer',
  'Educação',
  'Saúde',
  'Compras',
  'Outros',
];

const List<String> incomeCategories = <String>[
  'Salário',
  'Freelance',
  'Investimentos',
  'Outros',
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
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final data = await StorageService.read('finance');
    final result = <MoneyTransaction>[];
    for (final item in data) {
      result.add(MoneyTransaction.fromJson(item));
    }
    if (!mounted) return;
    setState(() {
      transactions = result;
    });
  }

  Future<void> saveTransactions() async {
    final data = <Map<String, dynamic>>[];
    for (final item in transactions) {
      data.add(item.toJson());
    }
    await StorageService.write('finance', data);
  }

  double sumTransactions(List<MoneyTransaction> list, bool income) {
    double total = 0;
    for (final item in list) {
      if (item.income == income) total += item.amount;
    }
    return total;
  }

  Future<void> editTransaction([MoneyTransaction? existing]) async {
    final description = TextEditingController(text: existing?.description ?? '');
    final amount = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2),
    );
    bool isIncome = existing?.income ?? false;
    String category = existing?.category ?? 'Outros';

    final saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final categories = isIncome ? incomeCategories : expenseCategories;
            if (!categories.contains(category)) {
              category = 'Outros';
            }
            return AlertDialog(
              title: Text(existing == null ? 'Nova movimentação' : 'Editar movimentação'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                    ),
                    const SizedBox(height: 8),
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
                      title: const Text('Entrada'),
                      value: isIncome,
                      onChanged: (bool value) {
                        setDialogState(() {
                          isIncome = value;
                          category = 'Outros';
                        });
                      },
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: category,
                      items: categories.map((String item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Text(item),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (value == null) return;
                        setDialogState(() {
                          category = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    final parsedAmount = double.tryParse(
      amount.text.trim().replaceAll(',', '.'),
    );
    if (saved != true || description.text.trim().isEmpty) return;
    if (parsedAmount == null || parsedAmount <= 0) return;

    final transaction = MoneyTransaction(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: existing?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
      description: description.text.trim(),
      category: category,
      amount: parsedAmount,
      income: isIncome,
    );

    transactions.removeWhere((item) => item.id == transaction.id);
    transactions.add(transaction);
    await saveTransactions();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> deleteTransaction(MoneyTransaction item) async {
    transactions.removeWhere((entry) => entry.id == item.id);
    await saveTransactions();
    if (!mounted) return;
    setState(() {});
  }

  String formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = DateFormat('yyyy-MM').format(selectedMonth);
    final monthItems = <MoneyTransaction>[];
    for (final item in transactions) {
      if (item.date.startsWith(monthKey)) monthItems.add(item);
    }
    monthItems.sort((a, b) => b.date.compareTo(a.date));

    final income = sumTransactions(monthItems, true);
    final expense = sumTransactions(monthItems, false);
    final totalIncome = sumTransactions(transactions, true);
    final totalExpense = sumTransactions(transactions, false);
    final currentBalance = totalIncome - totalExpense;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Financeiro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => editTransaction(),
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          AppCard(
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedMonth = DateTime(
                        selectedMonth.year,
                        selectedMonth.month - 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedMonth = DateTime(
                        selectedMonth.year,
                        selectedMonth.month + 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(child: metricCard('Entradas', income, Icons.arrow_downward)),
              Expanded(child: metricCard('Despesas', expense, Icons.arrow_upward)),
            ],
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Saldo atual',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'R$ ${currentBalance.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Resultado do mês: R$ ${(income - expense).toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Movimentações',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (monthItems.isEmpty)
            const AppCard(
              child: Text('Nenhuma movimentação neste mês.'),
            )
          else
            ...monthItems.map((item) {
              return AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(item.income ? Icons.add : Icons.remove),
                  ),
                  title: Text(item.description),
                  subtitle: Text('${item.category} • ${formatDate(item.date)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') editTransaction(item);
                      if (value == 'delete') deleteTransaction(item);
                    },
                    itemBuilder: (BuildContext context) {
                      return const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Excluir'),
                        ),
                      ];
                    },
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget metricCard(String label, double value, IconData icon) {
    return AppCard(
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
    );
  }
}
