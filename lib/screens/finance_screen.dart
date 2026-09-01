
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.read('finance');
    transactions = raw.map(MoneyTransaction.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() => StorageService.write(
        'finance',
        transactions.map((item) => item.toJson()).toList(),
      );

  Future<void> _addTransaction() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    bool income = false;
    String category = 'Outros';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova movimentação'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: ['Outros', 'Comida', 'Transporte', 'Lazer', 'Contas']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Categoria'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('É uma entrada?'),
                  value: income,
                  onChanged: (value) {
                    setDialogState(() => income = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );

    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (result != true ||
        description.text.trim().isEmpty ||
        value == null ||
        value <= 0) {
      return;
    }

    setState(() {
      transactions.add(
        MoneyTransaction(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          description: description.text.trim(),
          category: category,
          amount: value,
          income: income,
        ),
      );
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where((item) => item.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expenses = transactions
        .where((item) => !item.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final balance = income - expenses;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Financeiro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                onPressed: _addTransaction,
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldo'),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Entradas: R\$ ${income.toStringAsFixed(2)}'),
                Text('Despesas: R\$ ${expenses.toStringAsFixed(2)}'),
              ],
            ),
          ),
          if (transactions.isEmpty)
            const AppCard(child: Text('Nenhuma movimentação registrada.')),
          ...transactions.reversed.map(
            (item) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Icon(
                    item.income ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                ),
                title: Text(item.description),
                subtitle: Text(item.category),
                trailing: Text(
                  '${item.income ? '+' : '-'} R\$ ${item.amount.toStringAsFixed(2)}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
