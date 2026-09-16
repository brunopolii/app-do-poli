import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const expenseCategories = ['Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Educação', 'Saúde', 'Compras', 'Outros'];
const incomeCategories = ['Salário', 'Freelance', 'Investimentos', 'Outros'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> items = [];
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    items = (await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList();
    _refreshOverdue();
    loading = false;
    if (mounted) setState(() {});
  }
  void _refreshOverdue() {
    final now = DateTime.now();
    for (final x in items) {
      final d = DateTime.tryParse(x.dueDate);
      if (d != null && !x.isPaid && !x.isCancelled && d.isBefore(DateTime(now.year, now.month, now.day))) x.paymentStatus = 'overdue';
    }
  }
  Future<void> _save() => StorageService.write('finance', items.map((e) => e.toJson()).toList());
  String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
  bool _sameMonth(MoneyTransaction x, DateTime d) => x.date.startsWith(_monthKey(d));
  String _money(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  Iterable<MoneyTransaction> _monthItems(DateTime d) => items.where((x) => _sameMonth(x, d) && !x.isCancelled);
  double _sum(Iterable<MoneyTransaction> xs, bool income, {bool paidOnly = false}) => xs.where((x) => x.income == income && (!paidOnly || x.isPaid)).fold(0.0, (s, x) => s + x.amount);
  double _committed(DateTime d) => _monthItems(d).where((x) => !x.income && !x.isPaid).fold(0.0, (s, x) => s + x.amount);
  double _balance() => items.where((x) => x.isPaid && !x.isCancelled).fold(0.0, (s, x) => s + (x.income ? x.amount : -x.amount));

  Future<void> _addMenu() async {
    final choice = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('Movimentação única'), onTap: () => Navigator.pop(ctx, 'single')),
      ListTile(leading: const Icon(Icons.credit_card), title: const Text('Compra parcelada'), onTap: () => Navigator.pop(ctx, 'installment')),
      ListTile(leading: const Icon(Icons.repeat), title: const Text('Despesa recorrente'), onTap: () => Navigator.pop(ctx, 'recurring')),
    ])));
    if (choice == 'single') await _single();
    if (choice == 'installment') await _installment();
    if (choice == 'recurring') await _recurring();
  }

  Future<void> _single() async {
    final desc = TextEditingController();
    final amount = TextEditingController();
    bool income = false;
    String category = 'Outros';
    String status = 'paid';
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      final categories = income ? incomeCategories : expenseCategories;
      return AlertDialog(title: const Text('Nova movimentação'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrição')),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Entrada'), value: income, onChanged: (v) { setD(() { income = v; category = 'Outros'; status = 'paid'; }); }),
        DropdownButtonFormField<String>(initialValue: categories.contains(category) ? category : 'Outros', items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setD(() => category = v); }, decoration: const InputDecoration(labelText: 'Categoria')),
        if (!income) DropdownButtonFormField<String>(initialValue: status, items: const [DropdownMenuItem(value: 'paid', child: Text('Pago/realizado')), DropdownMenuItem(value: 'pending', child: Text('Previsto'))], onChanged: (v) { if (v != null) setD(() => status = v); }, decoration: const InputDecoration(labelText: 'Status')),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('Data: ${DateFormat('dd/MM/yyyy').format(date)}'), onTap: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (d != null) setD(() => date = d); }),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SALVAR'))]);
    }));
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (ok != true || desc.text.trim().isEmpty || value == null || value <= 0) return;
    final d = DateFormat('yyyy-MM-dd').format(date);
    items.add(MoneyTransaction(id: DateTime.now().microsecondsSinceEpoch.toString(), date: d, description: desc.text.trim(), category: category, amount: value, income: income, paymentStatus: income ? 'paid' : status, dueDate: d, paidDate: status == 'paid' ? d : null));
    await _save();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação salva com sucesso.'))); }
  }

  Future<void> _installment() async {
    final desc = TextEditingController();
    final total = TextEditingController();
    final part = TextEditingController();
    final count = TextEditingController(text: '2');
    bool totalMode = true;
    String category = 'Outros';
    DateTime first = DateTime.now();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: const Text('Compra parcelada'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrição')),
      DropdownButtonFormField<String>(initialValue: category, items: expenseCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setD(() => category = v); }, decoration: const InputDecoration(labelText: 'Categoria')),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Informar valor total'), value: totalMode, onChanged: (v) => setD(() => totalMode = v)),
      TextField(controller: totalMode ? total : part, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: totalMode ? 'Valor total' : 'Valor da parcela', prefixText: 'R\$ ')),
      TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade de parcelas')),
      ListTile(contentPadding: EdgeInsets.zero, title: Text('1ª parcela: ${DateFormat('dd/MM/yyyy').format(first)}'), onTap: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: first); if (d != null) setD(() => first = d); }),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CRIAR'))]));
    final n = int.tryParse(count.text);
    final base = double.tryParse((totalMode ? total : part).text.replaceAll(',', '.'));
    if (ok != true || desc.text.trim().isEmpty || n == null || n < 2 || base == null || base <= 0) return;
    final group = DateTime.now().microsecondsSinceEpoch.toString();
    final totalValue = totalMode ? base : base * n;
    final standard = totalMode ? totalValue / n : base;
    double allocated = 0;
    for (var i = 1; i <= n; i++) {
      final due = DateTime(first.year, first.month + i - 1, first.day);
      final value = i == n ? double.parse((totalValue - allocated).toStringAsFixed(2)) : double.parse(standard.toStringAsFixed(2));
      allocated += value;
      final date = DateFormat('yyyy-MM-dd').format(due);
      final paid = due.isBefore(DateTime.now()) || DateUtils.isSameDay(due, DateTime.now());
      items.add(MoneyTransaction(id: '$group-$i', date: date, description: desc.text.trim(), category: category, amount: value, income: false, paymentStatus: paid ? 'paid' : 'pending', isInstallment: true, installmentGroupId: group, totalInstallments: n, installmentNumber: i, totalAmount: totalValue, installmentAmount: value, dueDate: date, paidDate: paid ? date : null));
    }
    await _save();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compra parcelada criada com sucesso.'))); }
  }

  Future<void> _recurring() async {
    final desc = TextEditingController();
    final amount = TextEditingController();
    final months = TextEditingController(text: '12');
    String category = 'Outros';
    DateTime first = DateTime.now();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: const Text('Despesa recorrente'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrição')),
      DropdownButtonFormField<String>(initialValue: category, items: expenseCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setD(() => category = v); }, decoration: const InputDecoration(labelText: 'Categoria')),
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor por ocorrência', prefixText: 'R\$ ')),
      TextField(controller: months, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade de meses')),
      ListTile(contentPadding: EdgeInsets.zero, title: Text('Início: ${DateFormat('dd/MM/yyyy').format(first)}'), onTap: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: first); if (d != null) setD(() => first = d); }),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CRIAR'))]));
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    final n = int.tryParse(months.text);
    if (ok != true || desc.text.trim().isEmpty || value == null || value <= 0 || n == null || n < 1) return;
    final group = DateTime.now().microsecondsSinceEpoch.toString();
    for (var i = 0; i < n; i++) {
      final due = DateTime(first.year, first.month + i, first.day);
      final date = DateFormat('yyyy-MM-dd').format(due);
      final paid = due.isBefore(DateTime.now()) || DateUtils.isSameDay(due, DateTime.now());
      items.add(MoneyTransaction(id: 'r-$group-$i', date: date, description: desc.text.trim(), category: category, amount: value, income: false, paymentStatus: paid ? 'paid' : 'pending', isRecurring: true, recurrenceGroupId: group, recurrenceFrequency: 'monthly', recurrenceStartDate: DateFormat('yyyy-MM-dd').format(first), recurrenceEndDate: DateFormat('yyyy-MM-dd').format(DateTime(first.year, first.month + n - 1, first.day)), dueDate: date, paidDate: paid ? date : null));
    }
    await _save();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Despesa recorrente criada com sucesso.'))); }
  }

  Future<String?> _scope(String title) => showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: const Text('Escolha o alcance da alteração.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, 'one'), child: const Text('SOMENTE ESTA')), TextButton(onPressed: () => Navigator.pop(ctx, 'future'), child: const Text('ESTA E PRÓXIMAS')), FilledButton(onPressed: () => Navigator.pop(ctx, 'all'), child: const Text('TODA A SÉRIE'))]));

  Future<void> _togglePaid(MoneyTransaction x) async {
    if (x.isCancelled) return;
    if (x.isPaid) { x.paymentStatus = 'pending'; x.paidDate = null; } else { x.paymentStatus = 'paid'; x.paidDate = DateFormat('yyyy-MM-dd').format(DateTime.now()); }
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(MoneyTransaction x) async {
    String scope = 'one';
    if (x.isInstallment || x.isRecurring) scope = await _scope('Excluir lançamento') ?? 'cancel';
    if (scope == 'cancel') return;
    items.removeWhere((e) {
      if (scope == 'one') return e.id == x.id;
      if (x.isInstallment) return e.installmentGroupId == x.installmentGroupId && (scope == 'all' || e.installmentNumber >= x.installmentNumber);
      if (x.isRecurring) return e.recurrenceGroupId == x.recurrenceGroupId && (scope == 'all' || e.date.compareTo(x.date) >= 0);
      return e.id == x.id;
    });
    await _save();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item excluído.'))); }
  }

  Future<void> _edit(MoneyTransaction x) async {
    final desc = TextEditingController(text: x.description);
    final amount = TextEditingController(text: x.amount.toStringAsFixed(2));
    String category = x.category;
    String status = x.paymentStatus == 'overdue' ? 'pending' : x.paymentStatus;
    DateTime date = DateTime.tryParse(x.date) ?? DateTime.now();
    final categories = x.income ? incomeCategories : expenseCategories;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: const Text('Editar movimentação'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrição')),
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ')),
      DropdownButtonFormField<String>(initialValue: categories.contains(category) ? category : 'Outros', items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setD(() => category = v); }, decoration: const InputDecoration(labelText: 'Categoria')),
      DropdownButtonFormField<String>(initialValue: ['paid','pending','cancelled'].contains(status) ? status : 'pending', items: const [DropdownMenuItem(value: 'paid', child: Text('Pago/realizado')), DropdownMenuItem(value: 'pending', child: Text('Previsto')), DropdownMenuItem(value: 'cancelled', child: Text('Cancelado'))], onChanged: (v) { if (v != null) setD(() => status = v); }, decoration: const InputDecoration(labelText: 'Status')),
      ListTile(contentPadding: EdgeInsets.zero, title: Text('Data: ${DateFormat('dd/MM/yyyy').format(date)}'), onTap: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date); if (d != null) setD(() => date = d); }),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SALVAR'))]));
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (ok != true || desc.text.trim().isEmpty || value == null || value <= 0) return;
    String scope = 'one';
    if (x.isInstallment || x.isRecurring) scope = await _scope('Aplicar alteração') ?? 'cancel';
    if (scope == 'cancel') return;
    final targets = items.where((e) {
      if (scope == 'one') return e.id == x.id;
      if (x.isInstallment) return e.installmentGroupId == x.installmentGroupId && (scope == 'all' || e.installmentNumber >= x.installmentNumber);
      return e.recurrenceGroupId == x.recurrenceGroupId && (scope == 'all' || e.date.compareTo(x.date) >= 0);
    });
    for (final t in targets) { t.description = desc.text.trim(); t.amount = value; t.category = category; t.paymentStatus = status; if (scope == 'one') { t.date = DateFormat('yyyy-MM-dd').format(date); t.dueDate = t.date; } t.paidDate = status == 'paid' ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : null; if (t.isInstallment) t.installmentAmount = value; }
    await _save();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação atualizada.'))); }
  }

  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final current = _monthItems(month).toList()..sort((a,b) => a.date.compareTo(b.date));
    final income = _sum(current, true, paidOnly: true);
    final expense = _sum(current, false, paidOnly: true);
    final projectedIncome = _sum(current, true);
    final projectedExpense = _sum(current, false);
    final committed = _committed(month);
    final next = DateTime(month.year, month.month + 1);
    final nextCommitted = _committed(next);
    final categories = <String,double>{};
    for (final x in current.where((e) => !e.income)) categories[x.category] = (categories[x.category] ?? 0) + x.amount;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text('Financeiro', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: _addMenu, icon: const Icon(Icons.add), label: const Text('Adicionar'))]),
      AppCard(child: Row(children: [IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)), Expanded(child: Text(DateFormat('MMMM yyyy','pt_BR').format(month), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right))])),
      Row(children: [Expanded(child: _metric('Entradas realizadas', income)), Expanded(child: _metric('Despesas realizadas', expense))]),
      Row(children: [Expanded(child: _metric('Saldo atual', _balance())), Expanded(child: _metric('Resultado do mês', income - expense))]),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Compromissos e previsão', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Total comprometido: ${_money(committed)}'), Text('Entradas previstas: ${_money(projectedIncome)}'), Text('Despesas previstas: ${_money(projectedExpense)}'), Text('Saldo projetado: ${_money(projectedIncome - projectedExpense)}'), Text('Próximo mês comprometido: ${_money(nextCommitted)}'), const SizedBox(height: 6), Text('A projeção é baseada nos lançamentos cadastrados e não representa garantia do saldo bancário.', style: Theme.of(context).textTheme.bodySmall)])),
      if (categories.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Distribuição das despesas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 10), ...categories.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(e.key)), SizedBox(width: 100, child: LinearProgressIndicator(value: expense <= 0 ? 0 : (e.value / expense).clamp(0,1))), const SizedBox(width: 8), Text(_money(e.value))])))])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Próximos meses', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), ...List.generate(6, (i) { final m = DateTime(month.year, month.month + i); final xs = _monthItems(m).toList(); final inc = _sum(xs, true); final exp = _sum(xs, false); return ListTile(contentPadding: EdgeInsets.zero, title: Text(DateFormat('MMMM yyyy','pt_BR').format(m)), subtitle: Text('Entradas ${_money(inc)} • Comprometido ${_money(_committed(m))}'), trailing: Text(_money(inc-exp), style: const TextStyle(fontWeight: FontWeight.bold))); })])),
      const SizedBox(height: 4), Text('Movimentações', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      if (current.isEmpty) const AppCard(child: Text('Nenhuma movimentação neste mês.')),
      ...current.map((x) => AppCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Icon(x.income ? Icons.arrow_downward : Icons.arrow_upward)), title: Text(x.description), subtitle: Text('${x.category} • ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(x.date) ?? DateTime.now())} • ${x.paymentStatus}${x.isInstallment ? ' • ${x.installmentNumber}/${x.totalInstallments}' : ''}${x.isRecurring ? ' • recorrente' : ''}'), trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'pay') _togglePaid(x); if (v == 'edit') _edit(x); if (v == 'delete') _delete(x); }, itemBuilder: (_) => const [PopupMenuItem(value: 'pay', child: Text('Marcar pago/previsto')), PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))])))),
    ]));
  }
  Widget _metric(String label, double value) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_money(value), style: const TextStyle(fontWeight: FontWeight.bold)), Text(label, style: Theme.of(context).textTheme.bodySmall)]));
}
