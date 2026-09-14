import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> expenseCategories = <String>['Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Assinaturas', 'Outros'];
const List<String> incomeCategories = <String>['Salário', 'Renda extra', 'Freelance', 'Investimentos', 'Outros'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> items = <MoneyTransaction>[];
  List<RecurringTransaction> recurring = <RecurringTransaction>[];
  List<InstallmentPurchase> installments = <InstallmentPurchase>[];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await Future.wait([StorageService.read('finance'), StorageService.read('finance_recurring'), StorageService.read('finance_installments')]);
    items = data[0].map(MoneyTransaction.fromJson).toList();
    recurring = data[1].map(RecurringTransaction.fromJson).toList();
    installments = data[2].map(InstallmentPurchase.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await Future.wait([
      StorageService.write('finance', items.map((e) => e.toJson()).toList()),
      StorageService.write('finance_recurring', recurring.map((e) => e.toJson()).toList()),
      StorageService.write('finance_installments', installments.map((e) => e.toJson()).toList()),
    ]);
  }

  double _sum(Iterable<MoneyTransaction> list, bool income) => list.where((e) => e.income == income).fold(0.0, (sum, e) => sum + e.amount);
  DateTime _start(DateTime value) => DateTime(value.year, value.month);
  String _date(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String _money(double value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);

  List<RecurringTransaction> _recurringFor(DateTime target) => recurring.where((item) {
    final start = DateTime.tryParse(item.startDate);
    return start != null && !_start(target).isBefore(_start(start));
  }).toList();

  List<InstallmentPurchase> _installmentsFor(DateTime target) => installments.where((item) {
    final first = DateTime.tryParse(item.firstDate);
    if (first == null) return false;
    final distance = (target.year - first.year) * 12 + target.month - first.month;
    return distance >= 0 && distance < item.installments;
  }).toList();

  int _paidInstallments(InstallmentPurchase purchase) {
    final first = DateTime.tryParse(purchase.firstDate);
    if (first == null) return 0;
    final now = _start(DateTime.now());
    final passed = (now.year - first.year) * 12 + now.month - first.month + 1;
    return passed.clamp(0, purchase.installments).toInt();
  }

  Future<void> _editTransaction([MoneyTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(text: old == null ? '' : old.amount.toStringAsFixed(2));
    DateTime date = old == null ? DateTime.now() : DateTime.tryParse(old.date) ?? DateTime.now();
    bool income = old?.income ?? false;
    String category = old?.category ?? 'Outros';
    final saved = await showDialog<bool>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setDialog) {
      final categories = income ? incomeCategories : expenseCategories;
      if (!categories.contains(category)) category = 'Outros';
      return AlertDialog(title: Text(old == null ? 'Nova movimentação' : 'Editar movimentação'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: description, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Descrição')),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Data'), trailing: Text(DateFormat('dd/MM/yyyy').format(date)), onTap: () async { final value = await showDatePicker(context: dialog, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (value != null) setDialog(() => date = value); }),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('É uma receita'), value: income, onChanged: (value) => setDialog(() { income = value; category = 'Outros'; })),
        DropdownButtonFormField<String>(initialValue: category, isExpanded: true, items: categories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) { if (value != null) setDialog(() => category = value); }, decoration: const InputDecoration(labelText: 'Categoria')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar'))]);
    }));
    final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (saved != true || description.text.trim().isEmpty || value == null || value <= 0) return;
    final transaction = MoneyTransaction(id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), date: _date(date), description: description.text.trim(), category: category, amount: value, income: income);
    items.removeWhere((item) => item.id == transaction.id); items.add(transaction); await _save(); if (mounted) setState(() {});
  }

  Future<void> _editRecurring([RecurringTransaction? old]) async {
    final description = TextEditingController(text: old?.description ?? '');
    final amount = TextEditingController(text: old?.amount.toStringAsFixed(2) ?? '');
    DateTime start = old == null ? DateTime.now() : DateTime.tryParse(old.startDate) ?? DateTime.now();
    bool income = old?.income ?? false; String category = old?.category ?? 'Assinaturas'; int day = old?.dayOfMonth ?? DateTime.now().day;
    final saved = await showDialog<bool>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setDialog) {
      final categories = income ? incomeCategories : expenseCategories; if (!categories.contains(category)) category = 'Outros';
      return AlertDialog(title: Text(old == null ? 'Nova recorrência' : 'Editar recorrência'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição (ex.: Netflix)')),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor mensal', prefixText: 'R\$ ')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('É uma receita recorrente'), value: income, onChanged: (v) => setDialog(() { income = v; category = 'Outros'; })),
        DropdownButtonFormField<String>(initialValue: category, items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setDialog(() => category = v); }, decoration: const InputDecoration(labelText: 'Categoria')),
        ListTile(contentPadding: EdgeInsets.zero, title: const Text('Início'), trailing: Text(DateFormat('dd/MM/yyyy').format(start)), onTap: () async { final v = await showDatePicker(context: dialog, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: start); if (v != null) setDialog(() { start = v; day = v.day; }); }),
        DropdownButtonFormField<int>(initialValue: day, items: List.generate(31, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('Dia $v'))).toList(), onChanged: (v) { if (v != null) setDialog(() => day = v); }, decoration: const InputDecoration(labelText: 'Dia de vencimento')),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar'))]);
    }));
    final value = double.tryParse(amount.text.trim().replaceAll(',', '.')); if (saved != true || description.text.trim().isEmpty || value == null || value <= 0) return;
    final item = RecurringTransaction(id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), description: description.text.trim(), category: category, amount: value, income: income, startDate: _date(start), dayOfMonth: day);
    recurring.removeWhere((e) => e.id == item.id); recurring.add(item); await _save(); if (mounted) setState(() {});
  }

  Future<void> _addInstallment() async {
    final description = TextEditingController(); final total = TextEditingController(); final count = TextEditingController(text: '2'); String category = 'Compras'; DateTime first = DateTime.now();
    final saved = await showDialog<bool>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(title: const Text('Compra parcelada'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
      TextField(controller: total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor total', prefixText: 'R\$ ')),
      TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de parcelas')),
      DropdownButtonFormField<String>(initialValue: category, items: expenseCategories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) { if (v != null) setDialog(() => category = v); }, decoration: const InputDecoration(labelText: 'Categoria')),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Primeira parcela'), trailing: Text(DateFormat('dd/MM/yyyy').format(first)), onTap: () async { final v = await showDatePicker(context: dialog, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: first); if (v != null) setDialog(() => first = v); }),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Salvar'))])));
    final value = double.tryParse(total.text.replaceAll(',', '.')); final parts = int.tryParse(count.text); if (saved != true || description.text.trim().isEmpty || value == null || value <= 0 || parts == null || parts < 2) return;
    installments.add(InstallmentPurchase(id: DateTime.now().microsecondsSinceEpoch.toString(), description: description.text.trim(), category: category, totalAmount: value, installments: parts, firstDate: _date(first))); await _save(); if (mounted) setState(() {});
  }

  Future<void> _chooseAdd() async {
    final choice = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('Movimentação avulsa'), subtitle: const Text('Receita ou despesa em uma data específica'), onTap: () => Navigator.pop(context, 'transaction')),
      ListTile(leading: const Icon(Icons.repeat), title: const Text('Receita ou despesa recorrente'), subtitle: const Text('Salário, assinatura, mensalidade ou conta'), onTap: () => Navigator.pop(context, 'recurring')),
      ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Compra parcelada'), subtitle: const Text('Controla parcelas e previsão futura'), onTap: () => Navigator.pop(context, 'installment')),
    ])));
    if (choice == 'transaction') await _editTransaction(); if (choice == 'recurring') await _editRecurring(); if (choice == 'installment') await _addInstallment();
  }

  @override
  Widget build(BuildContext context) {
    final currentManual = items.where((e) => e.date.startsWith(DateFormat('yyyy-MM').format(month))).toList();
    currentManual.sort((a, b) => b.date.compareTo(a.date));
    final currentRecurring = _recurringFor(month); final currentInstallments = _installmentsFor(month);
    final income = _sum(currentManual, true) + currentRecurring.where((e) => e.income).fold(0.0, (s, e) => s + e.amount);
    final expense = _sum(currentManual, false) + currentRecurring.where((e) => !e.income).fold(0.0, (s, e) => s + e.amount) + currentInstallments.fold(0.0, (s, e) => s + e.installmentAmount);
    final balance = _sum(items, true) - _sum(items, false);
    return SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text('Financeiro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))), IconButton(tooltip: 'Adicionar', onPressed: _chooseAdd, icon: const Icon(Icons.add_circle_outline))]),
      AppCard(child: Row(children: [IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)), Expanded(child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))), IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right))])),
      Row(children: [Expanded(child: _metric('Receitas', income, Icons.south_west)), Expanded(child: _metric('Despesas', expense, Icons.north_east))]),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Saldo atual', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(_money(balance), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), Text('Resultado do mês: ${_money(income - expense)}') ])),
      _forecast(context),
      if (recurring.isNotEmpty) _recurringCard(context),
      if (installments.isNotEmpty) _installmentCard(context),
      Text('Movimentações do mês', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
      if (currentManual.isEmpty) const AppCard(child: Text('Nenhuma movimentação avulsa neste mês. As previsões aparecem acima.')),
      ...currentManual.map((item) => AppCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Icon(item.income ? Icons.add : Icons.remove)), title: Text(item.description), subtitle: Text('${item.category} • ${item.date.split('-').reversed.join('/')}'), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await _editTransaction(item); if (v == 'delete') { items.remove(item); await _save(); if (mounted) setState(() {}); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))])))),
    ]));
  }

  Widget _metric(String label, double value, IconData icon) => AppCard(child: Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_money(value), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)), Text(label)]))]));

  Widget _forecast(BuildContext context) {
    final next = DateTime(month.year, month.month + 1); final manual = items.where((e) => e.date.startsWith(DateFormat('yyyy-MM').format(next))).toList(); final repeat = _recurringFor(next); final parts = _installmentsFor(next);
    final received = _sum(manual, true) + repeat.where((e) => e.income).fold(0.0, (s, e) => s + e.amount); final recurringExpenses = repeat.where((e) => !e.income).fold(0.0, (s, e) => s + e.amount); final installmentExpenses = parts.fold(0.0, (s, e) => s + e.installmentAmount); final other = _sum(manual, false); final available = received - recurringExpenses - installmentExpenses - other;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Previsão para ${DateFormat('MMMM', 'pt_BR').format(next)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), _line('Receitas previstas', received), _line('Despesas recorrentes', recurringExpenses), _line('Parcelas', installmentExpenses), _line('Outras despesas previstas', other), const Divider(), _line('Saldo previsto', available, bold: true), const SizedBox(height: 8), Text('Inclui recorrências, parcelas ainda pendentes e movimentações futuras já cadastradas.', style: Theme.of(context).textTheme.bodySmall)]));
  }
  Widget _line(String label, double value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(child: Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null)), Text(_money(value), style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null)]));
  Widget _recurringCard(BuildContext context) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Recorrências', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), ...recurring.map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item.description), subtitle: Text('${item.income ? 'Receita' : item.category} • dia ${item.dayOfMonth}'), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await _editRecurring(item); if (v == 'delete') { recurring.remove(item); await _save(); if (mounted) setState(() {}); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))], child: Text(_money(item.amount))))]));
  Widget _installmentCard(BuildContext context) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Compras parceladas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), ...installments.map((item) { final paid = _paidInstallments(item); return ListTile(contentPadding: EdgeInsets.zero, title: Text(item.description), subtitle: Text('${_money(item.installmentAmount)} por mês • $paid de ${item.installments} parcelas pagas'), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'delete') { installments.remove(item); await _save(); if (mounted) setState(() {}); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Excluir'))])); })]));
}
