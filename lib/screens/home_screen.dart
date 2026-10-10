import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/date_formatters.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';
import 'home_customization_screen.dart';
import 'weekly_report_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenTheme;
  final ValueChanged<int>? onNavigate;
  const HomeScreen({super.key, this.onOpenTheme, this.onNavigate});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<AgendaEvent> events = [];
  List<Meal> meals = [];
  List<MoneyTransaction> money = [];
  List<Workout> workouts = [];
  List<Map<String, dynamic>> cards = HomeCardSettings.defaults();
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final loadedEvents = (await StorageService.read('agenda')).map(AgendaEvent.fromJson).toList();
    final loadedMeals = (await StorageService.read('meals')).map(Meal.fromJson).toList();
    final loadedMoney = (await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList();
    final loadedWorkouts = (await StorageService.read('workout_history')).map(Workout.fromJson).toList();
    final loadedCards = await HomeCardSettings.load();
    if (!mounted) return;
    setState(() {
      events = loadedEvents; meals = loadedMeals; money = loadedMoney;
      workouts = loadedWorkouts; cards = loadedCards; loading = false;
    });
  }

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    await _load();
  }

  double _food(Iterable<Meal> x, int t) => x.fold(0.0,
    (s, m) => s + (t == 0 ? m.calories : t == 1 ? m.protein : t == 2 ? m.carbs : m.fat));

  double _cash(Iterable<MoneyTransaction> x, bool income, {bool paid = false}) => x
      .where((m) => m.income == income && (!paid || m.isPaid) && !m.isCancelled)
      .fold(0.0, (s, m) => s + m.amount);

  String _money(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _customize() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => HomeCustomizationScreen(initialCards: cards),
    ));
    if (changed == true) await refresh();
  }

  void _go(int index) => widget.onNavigate?.call(index);
  Future<void> _openWeeklyReport() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const WeeklyReportScreen()));
  }

  Widget _counter(IconData icon, String label, int value) => Expanded(
    child: Column(children: [
      Icon(icon), const SizedBox(height: 4),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ]),
  );

  Widget _stat(String value, String label) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]),
  );

  Widget _card(Map<String, dynamic> config, Widget child, {VoidCallback? onTap}) {
    final size = (config['size'] ?? 'normal').toString();
    final titleStyle = size == 'large'
        ? Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
        : size == 'compact'
            ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
            : Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    return AppCard(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: size == 'compact' ? 0 : size == 'large' ? 7 : 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((config['title'] ?? 'Cartão').toString(), style: titleStyle),
          SizedBox(height: size == 'compact' ? 6 : 10),
          child,
        ]),
      ),
    ));
  }

  Widget _buildCard(Map<String, dynamic> config, DateTime now, String today, List<AgendaEvent> upcoming, List<Meal> todayMeals, Iterable<MoneyTransaction> currentMonth, double income, double expense, double balance) {
    final type = (config['type'] ?? 'overview').toString();
    switch (type) {
      case 'overview':
        final metrics = (config['metrics'] as List? ?? []).cast<String>();
        return _card(config, Row(children: [
          if (metrics.contains('agenda')) _counter(Icons.event_outlined, 'Compromissos', events.where((e) => e.date == today).length),
          if (metrics.contains('gym')) _counter(Icons.fitness_center, 'Treinos', workouts.where((w) => w.date == today).length),
          if (metrics.contains('food')) _counter(Icons.restaurant_outlined, 'Refeições', todayMeals.length),
        ]));
      case 'quick':
        final metrics = (config['metrics'] as List? ?? []).cast<String>();
        return _card(config, Wrap(spacing: 8, runSpacing: 8, children: [
          if (metrics.contains('agenda')) _quickAction(Icons.event_outlined, 'Compromisso', () => _go(0)),
          if (metrics.contains('gym')) _quickAction(Icons.fitness_center, 'Treino', () => _go(1)),
          if (metrics.contains('food')) _quickAction(Icons.restaurant_outlined, 'Refeição', () => _go(3)),
          if (metrics.contains('finance')) _quickAction(Icons.account_balance_wallet_outlined, 'Finanças', () => _go(4)),
        ]));
      case 'agenda':
        return _card(config, upcoming.isEmpty
          ? const Text('Nada agendado para os próximos dias.')
          : Column(children: upcoming.take(config['size'] == 'compact' ? 2 : 4).map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.event)),
              title: Text(e.title),
              subtitle: Text('${e.date} • ${e.start}–${e.end}'),
              dense: config['size'] == 'compact',
              onTap: () => _go(0),
            )).toList()), onTap: () => _go(0));
      case 'gym':
        final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final weekWorkouts = workouts.where((w) {
          final d = DateTime.tryParse(w.date);
          return d != null && !DateTime(d.year, d.month, d.day).isBefore(weekStart);
        }).length;
        final recent = workouts.toList()..sort((a, b) => b.date.compareTo(a.date));
        final metrics = (config['metrics'] as List? ?? []).cast<String>();
        return _card(config, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (metrics.contains('workouts')) Text('$weekWorkouts treino(s) nesta semana', style: Theme.of(context).textTheme.titleMedium),
          if (metrics.contains('last') && recent.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Último treino: ${recent.first.name} • ${recent.first.date}'),
          ],
          if (recent.isEmpty) const Text('Registre seu primeiro treino para acompanhar sua evolução.'),
        ]), onTap: () => _go(1));
      case 'food':
        final compact = config['size'] == 'compact';
        final metrics = (config['metrics'] as List? ?? []).cast<String>();
        return _card(config, Wrap(spacing: 8, runSpacing: 10, children: [
          if (!compact || metrics.contains('calories')) _smallMetric(_food(todayMeals, 0).toStringAsFixed(0), 'kcal'),
          if (!compact || metrics.contains('protein')) _smallMetric('${_food(todayMeals, 1).toStringAsFixed(0)} g', 'proteína'),
          if (!compact || metrics.contains('carbs')) _smallMetric('${_food(todayMeals, 2).toStringAsFixed(0)} g', 'carboidratos'),
          if (!compact || metrics.contains('fat')) _smallMetric('${_food(todayMeals, 3).toStringAsFixed(0)} g', 'gorduras'),
        ]), onTap: () => _go(3));
      case 'finance':
        final metrics = (config['metrics'] as List? ?? []).cast<String>();
        return _card(config, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (metrics.contains('income')) _stat(_money(income), 'entradas'),
            if (metrics.contains('expense')) _stat(_money(expense), 'despesas'),
            if (metrics.contains('balance')) _stat(_money(income - expense), 'resultado'),
          ]),
          const SizedBox(height: 8),
          Text('Saldo atual: ${_money(balance)}'),
          if (config['size'] == 'large') Text('Movimentações no mês: ${currentMonth.where((m) => !m.isCancelled).length}'),
        ]), onTap: () => _go(4));
      case 'alerts':
        final todayDate = DateTime(now.year, now.month, now.day);
        final urgent = money.where((m) {
          if (m.income || m.isCancelled || m.isPaid) return false;
          final d = DateTime.tryParse(m.dueDate);
          return d != null && !d.isBefore(todayDate) && !d.isAfter(todayDate.add(const Duration(days: 7)));
        }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        final todayEvents = events.where((e) => e.date == today).length;
        final metrics = (config['metrics'] as List? ?? []).cast<String>();
        return _card(config, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (metrics.contains('appointments')) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_available_outlined), title: Text('$todayEvents compromisso(s) hoje'), onTap: () => _go(0)),
          if (metrics.contains('bills')) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.payments_outlined), title: Text('${urgent.length} despesa(s) pendente(s) nos próximos 7 dias'), onTap: () => _go(4)),
          if (metrics.contains('bills') && urgent.isNotEmpty) Text('Próxima: ${urgent.first.description} • ${urgent.first.dueDate}'),
        ]));
      case 'weekly':
        final metrics = (config['metrics'] as List? ?? []).cast<String>();
        final labels = <String>[
          if (metrics.contains('workouts')) 'Academia',
          if (metrics.contains('meals')) 'Alimentação',
          if (metrics.contains('finance')) 'Financeiro',
        ];
        return _card(config, Row(children: [
          const Icon(Icons.insights_outlined, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(labels.isEmpty ? 'Relatório sem módulos selecionados.' : 'Comparação semanal: ${labels.join(' • ')}')),
          const Icon(Icons.chevron_right),
        ]), onTap: _openWeeklyReport);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) => ActionChip(
    avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap);

  Widget _smallMetric(String value, String label) => SizedBox(width: 130,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final upcoming = events.where((e) {
      final d = DateTime.tryParse(e.date);
      return d != null && !DateTime(d.year, d.month, d.day).isBefore(DateTime(now.year, now.month, now.day));
    }).toList()..sort((a, b) => '${a.date} ${a.start}'.compareTo('${b.date} ${b.start}'));
    final todayMeals = meals.where((e) => e.date == today).toList();
    final currentMonth = money.where((x) => x.date.startsWith(DateFormat('yyyy-MM').format(now)));
    final income = _cash(currentMonth, true, paid: true);
    final expense = _cash(currentMonth, false, paid: true);
    final balance = _cash(money, true, paid: true) - _cash(money, false, paid: true);

    return SafeArea(child: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Olá! 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(formatFullDatePtBr(now)),
            ])),
            IconButton(tooltip: 'Personalizar início', onPressed: _customize, icon: const Icon(Icons.dashboard_customize_outlined)),
            IconButton(tooltip: 'Personalizar tema', onPressed: widget.onOpenTheme, icon: const Icon(Icons.palette_outlined)),
          ]),
          ...cards.where((c) => c['visible'] != false).map((c) => _buildCard(c, now, today, upcoming, todayMeals, currentMonth, income, expense, balance)),
          if (cards.every((c) => c['visible'] == false))
            AppCard(child: Column(children: [
              const Text('Sua tela inicial está vazia.'),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: _customize, icon: const Icon(Icons.tune), label: const Text('Personalizar início')),
            ])),
        ],
      ),
    ));
  }
}
