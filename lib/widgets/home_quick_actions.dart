
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/storage_service.dart';

class HomeQuickActions {
  static const _expenseCategories = [
    'Alimentação', 'Transporte', 'Moradia', 'Lazer',
    'Educação', 'Saúde', 'Compras', 'Outros',
  ];
  static const _incomeCategories = [
    'Salário', 'Freelance', 'Investimentos', 'Outros',
  ];

  static const _options = <_QuickActionOption>[
    _QuickActionOption(
      id: 'expense',
      title: 'Despesa',
      subtitle: 'Registrar um gasto',
      icon: Icons.receipt_long_outlined,
    ),
    _QuickActionOption(
      id: 'income',
      title: 'Entrada',
      subtitle: 'Registrar dinheiro recebido',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _QuickActionOption(
      id: 'weight',
      title: 'Peso',
      subtitle: 'Registrar peso corporal',
      icon: Icons.monitor_weight_outlined,
    ),
    _QuickActionOption(
      id: 'food',
      title: 'Comida',
      subtitle: 'Registrar uma refeição',
      icon: Icons.restaurant_outlined,
    ),
  ];

  static Future<bool> show(
    BuildContext context, {
    List<String>? enabledActions,
  }) async {
    const allActions = ['expense', 'income', 'weight', 'food'];
    final selectedActions = enabledActions == null || enabledActions.isEmpty
        ? allActions.toSet()
        : enabledActions.toSet();
    final options = _options
        .where((option) => selectedActions.contains(option.id))
        .toList();
    final availableOptions = options.isEmpty ? _options : options;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O que deseja adicionar?',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.15,
                children: availableOptions.map((option) {
                  return Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(option.id),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(option.icon, size: 25),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option.subtitle,
                                    style: Theme.of(sheetContext).textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) return false;
    switch (action) {
      case 'expense':
        return _addMoney(context, income: false);
      case 'income':
        return _addMoney(context, income: true);
      case 'weight':
        return _addWeight(context);
      case 'food':
        return _addFood(context);
    }
    return false;
  }

  static Future<bool> _addMoney(
    BuildContext context, {
    required bool income,
  }) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var category = income ? _incomeCategories.first : _expenseCategories.last;
    var paid = income;
    var dueDate = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: Text(income ? 'Adicionar entrada' : 'Adicionar despesa'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Informe uma descrição'
                          : null,
                    ),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        prefixText: r'R$ ',
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                          (value ?? '').trim().replaceAll(',', '.'),
                        );
                        if (amount == null || !amount.isFinite || amount <= 0) {
                          return 'Informe um valor maior que zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: (income ? _incomeCategories : _expenseCategories)
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) update(() => category = value);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        (income ? 'Data: ' : 'Vencimento: ') +
                            DateFormat('dd/MM/yyyy').format(dueDate),
                      ),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        final result = await showDatePicker(
                          context: dialogContext,
                          initialDate: dueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (result != null) update(() => dueDate = result);
                      },
                    ),
                    if (!income)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Despesa já foi paga'),
                        value: paid,
                        onChanged: (value) => update(() => paid = value),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    final description = descriptionController.text.trim();
    final amount = double.tryParse(
      amountController.text.trim().replaceAll(',', '.'),
    );
    descriptionController.dispose();
    amountController.dispose();
    if (ok != true || description.isEmpty || amount == null || amount <= 0) {
      return false;
    }

    final date = DateFormat('yyyy-MM-dd').format(dueDate);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final transaction = MoneyTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: date,
      description: description,
      category: category,
      amount: amount,
      income: income,
      paymentStatus: income ? 'paid' : (paid ? 'paid' : 'pending'),
      dueDate: date,
      paidDate: paid ? today : null,
    );
    final transactions = await StorageService.read('finance');
    transactions.add(transaction.toJson());
    await StorageService.write('finance', transactions);
    if (!context.mounted) return true;
    _notify(context, income ? 'Entrada adicionada.' : 'Despesa adicionada.');
    return true;
  }

  static Future<bool> _addWeight(BuildContext context) async {
    final weightController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var date = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Adicionar peso'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso corporal',
                    suffixText: 'kg',
                  ),
                  validator: (value) {
                    final weight = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );
                    if (weight == null || !weight.isFinite || weight <= 0) {
                      return 'Informe um peso válido';
                    }
                    return null;
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data: ${DateFormat('dd/MM/yyyy').format(date)}'),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final result = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (result != null) update(() => date = result);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    final weight = double.tryParse(
      weightController.text.trim().replaceAll(',', '.'),
    );
    weightController.dispose();
    if (ok != true || weight == null || weight <= 0) return false;

    final now = DateTime.now();
    final timestamp = DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
    );
    final records = await StorageService.read('body_weights');
    records.add(WeightEntry(date: timestamp.toIso8601String(), weight: weight).toJson());
    await StorageService.write('body_weights', records);
    if (!context.mounted) return true;
    _notify(context, 'Peso registrado.');
    return true;
  }

  static Future<bool> _addFood(BuildContext context) async {
    final nameController = TextEditingController();
    final portionController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var date = DateTime.now();

    String? optionalNumberValidator(String? value) {
      if ((value ?? '').trim().isEmpty) return null;
      final number = double.tryParse(value!.trim().replaceAll(',', '.'));
      if (number == null || !number.isFinite || number < 0) {
        return 'Informe um número válido ou deixe vazio';
      }
      return null;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Adicionar comida'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Alimento'),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Informe o alimento'
                          : null,
                    ),
                    TextFormField(
                      controller: portionController,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade / porção (opcional)',
                      ),
                    ),
                    TextFormField(
                      controller: caloriesController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Calorias (kcal)'),
                      validator: optionalNumberValidator,
                    ),
                    TextFormField(
                      controller: proteinController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Proteína (g)'),
                      validator: optionalNumberValidator,
                    ),
                    TextFormField(
                      controller: carbsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Carboidratos (g)'),
                      validator: optionalNumberValidator,
                    ),
                    TextFormField(
                      controller: fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Gorduras (g)'),
                      validator: optionalNumberValidator,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Data: ${DateFormat('dd/MM/yyyy').format(date)}'),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        final result = await showDatePicker(
                          context: dialogContext,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (result != null) update(() => date = result);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    final portion = portionController.text.trim();
    double amount(TextEditingController controller) =>
        double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    final calories = amount(caloriesController);
    final protein = amount(proteinController);
    final carbs = amount(carbsController);
    final fat = amount(fatController);
    for (final controller in [
      nameController,
      portionController,
      caloriesController,
      proteinController,
      carbsController,
      fatController,
    ]) {
      controller.dispose();
    }
    if (ok != true || name.isEmpty) return false;

    final meal = Meal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateFormat('yyyy-MM-dd').format(date),
      type: 'Refeição',
      food: portion.isEmpty ? name : '$name ($portion)',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      source: 'manual',
    );
    final meals = await StorageService.read('meals');
    meals.add(meal.toJson());
    await StorageService.write('meals', meals);
    if (!context.mounted) return true;
    _notify(context, 'Refeição adicionada.');
    return true;
  }

  static void _notify(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _QuickActionOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _QuickActionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
