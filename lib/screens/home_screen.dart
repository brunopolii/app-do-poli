import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AgendaEvent> events = <AgendaEvent>[];
  List<Meal> meals = <Meal>[];
  List<MoneyTransaction> money = <MoneyTransaction>[];
  List<WorkoutPlan> plans = <WorkoutPlan>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final agendaData = await StorageService.read('agenda');
      final mealData = await StorageService.read('meals');
      final financeData = await StorageService.read('finance');
      final workoutData = await StorageService.read('workout_plans');
      events = agendaData.map(AgendaEvent.fromJson).toList();
      meals = mealData.map(Meal.fromJson).toList();
      money = financeData.map(MoneyTransaction.fromJson).toList();
      plans = workoutData.map(WorkoutPlan.fromJson).toList();
    } catch (_) {
      events = <AgendaEvent>[];
      meals = <Meal>[];
      money = <MoneyTransaction>[];
      plans = <WorkoutPlan>[];
    }
    if (!mounted) return;
    setState(() { loading = false; });
  }

  double _food(Iterable<Meal> list, int type) {
    double total = 0;
    for (final item in list) {
      if (type == 0) total += item.calories;
      if (type == 1) total += item.protein;
      if (type == 2) total += item.carbs;
      if (type == 3) total += item.fat;
    }
    return total;
  }

  double _cash(Iterable<MoneyTransaction> list, bool income) {
    double total = 0;
    for (final item in list) {
      if (item.income == income) total += item.amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final month = DateFormat('yyyy-MM').format(now);
    final todayEvents = events.where((e) => e.date == today).toList();
    final todayMeals = meals.where((e) => e.date == today).toList();
    final todayPlans = plans.where((e) => e.weekdays.contains(now.weekday)).toList();
    final monthMoney = money.where((e) => e.date.startsWith(month)).toList();
    todayEvents.sort((a, b) => a.start.compareTo(b.start));
    final income = _cash(monthMoney, true);
    final expense = _cash(monthMoney, false);
    final balance = _cash(money, true) - _cash(money, false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Olá! 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(now)),
          const SizedBox(height: 16),
          _card(context, 'Resumo de hoje', Row(children: <Widget>[
            _counter(context, Icons.event_outlined, 'Agenda', todayEvents.length.toString()),
            _counter(context, Icons.fitness_center, 'Treinos', todayPlans.length.toString()),
            _counter(context, Icons.restaurant_outlined, 'Refeições', todayMeals.length.toString()),
          ])),
          _card(context, 'Próximo compromisso', todayEvents.isEmpty ? const Text('Nada agendado para hoje.') : ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.event)),
            title: Text(todayEvents.first.title),
            subtitle: Text('${todayEvents.first.start} • ${todayEvents.first.end}'),
          )),
          _card(context, 'Alimentação de hoje', Row(children: <Widget>[
            _stat(context, _food(todayMeals, 0).toStringAsFixed(0), 'kcal'),
            _stat(context, '${_food(todayMeals, 1).toStringAsFixed(0)}g', 'proteína'),
            _stat(context, '${_food(todayMeals, 2).toStringAsFixed(0)}g', 'carbo'),
            _stat(context, '${_food(todayMeals, 3).toStringAsFixed(0)}g', 'gordura'),
          ])),
          _card(context, 'Financeiro do mês', Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              _stat(context, r'R$ ' + income.toStringAsFixed(0), 'entradas'),
              _stat(context, r'R$ ' + expense.toStringAsFixed(0), 'despesas'),
              _stat(context, r'R$ ' + (income - expense).toStringAsFixed(0), 'resultado'),
            ]),
            const SizedBox(height: 10),
            Text(r'Saldo atual: R$ ' + balance.toStringAsFixed(2)),
          ])),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, Widget child) {
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      child,
    ]));
  }

  Widget _counter(BuildContext context, IconData icon, String label, String value) {
    return Expanded(child: Column(children: <Widget>[
      Icon(icon),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]));
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
}
