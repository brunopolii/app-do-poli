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
  List<MoneyTransaction> finance = <MoneyTransaction>[];
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
      final planData = await StorageService.read('workout_plans');
      events = agendaData.map(AgendaEvent.fromJson).toList();
      meals = mealData.map(Meal.fromJson).toList();
      finance = financeData.map(MoneyTransaction.fromJson).toList();
      plans = planData.map(WorkoutPlan.fromJson).toList();
    } catch (_) {
      events = <AgendaEvent>[];
      meals = <Meal>[];
      finance = <MoneyTransaction>[];
      plans = <WorkoutPlan>[];
    }
    if (mounted) setState(() => loading = false);
  }

  double _mealTotal(List<Meal> source, double Function(Meal) getValue) {
    double total = 0;
    for (final item in source) total += getValue(item);
    return total;
  }

  double _moneyTotal(bool income, [Iterable<MoneyTransaction>? source]) {
    final values = source ?? finance;
    double total = 0;
    for (final item in values) {
      if (item.income == income) total += item.amount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final todayEvents = events.where((item) => item.date == today).toList();
    todayEvents.sort((a, b) => a.start.compareTo(b.start));
    final todayMeals = meals.where((item) => item.date == today).toList();
    final todayPlans = plans.where((item) => item.weekdays.contains(now.weekday)).toList();

    final calories = _mealTotal(todayMeals, (item) => item.calories);
    final protein = _mealTotal(todayMeals, (item) => item.protein);
    final carbs = _mealTotal(todayMeals, (item) => item.carbs);
    final fat = _mealTotal(todayMeals, (item) => item.fat);

    final monthKey = DateFormat('yyyy-MM').format(now);
    final monthFinance = finance.where((item) => item.date.startsWith(monthKey)).toList();
    final monthIncome = _moneyTotal(true, monthFinance);
    final monthExpense = _moneyTotal(false, monthFinance);
    final currentBalance = _moneyTotal(true) - _moneyTotal(false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text('Olá! 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(now)),
          const SizedBox(height: 16),
          _summary(todayEvents.length, todayPlans.length, todayMeals.length),
          _agenda(todayEvents),
          _food(calories, protein, carbs, fat),
          _finance(monthIncome, monthExpense, currentBalance),
          if (todayPlans.isNotEmpty) _workouts(todayPlans, now.weekday),
        ],
      ),
    );
  }

  Widget _summary(int agenda, int workouts, int food) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Resumo de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(children: <Widget>[
            _counter(Icons.event_outlined, 'Agenda', agenda.toString()),
            _counter(Icons.fitness_center, 'Treinos', workouts.toString()),
            _counter(Icons.restaurant_outlined, 'Refeições', food.toString()),
          ]),
        ],
      ),
    );
  }

  Widget _agenda(List<AgendaEvent> items) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Próximo compromisso', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('Nada agendado para hoje.')
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.event)),
              title: Text(items.first.title),
              subtitle: Text('${items.first.start} • ${items.first.end}'),
            ),
        ],
      ),
    );
  }

  Widget _food(double calories, double protein, double carbs, double fat) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Alimentação de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(children: <Widget>[
            _stat(calories.toStringAsFixed(0), 'kcal'),
            _stat('${protein.toStringAsFixed(0)}g', 'proteína'),
            _stat('${carbs.toStringAsFixed(0)}g', 'carbo'),
            _stat('${fat.toStringAsFixed(0)}g', 'gordura'),
          ]),
        ],
      ),
    );
  }

  Widget _finance(double income, double expense, double balance) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Financeiro do mês', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(children: <Widget>[
            _stat('R$ ${income.toStringAsFixed(0)}', 'entradas'),
            _stat('R$ ${expense.toStringAsFixed(0)}', 'despesas'),
            _stat('R$ ${(income - expense).toStringAsFixed(0)}', 'resultado'),
          ]),
          const SizedBox(height: 10),
          Text('Saldo atual: R$ ${balance.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _workouts(List<WorkoutPlan> items, int weekday) {
    final children = <Widget>[
      Text('Treinos de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    ];
    for (final plan in items) {
      children.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
          title: Text(plan.name),
          subtitle: Text('${plan.exercisesFor(weekday).length} exercícios'),
        ),
      );
    }
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }

  Widget _counter(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
