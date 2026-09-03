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
      final agenda = await StorageService.read('agenda');
      final food = await StorageService.read('meals');
      final money = await StorageService.read('finance');
      final workouts = await StorageService.read('workout_plans');
      events = agenda.map((item) => AgendaEvent.fromJson(item)).toList();
      meals = food.map((item) => Meal.fromJson(item)).toList();
      finance = money.map((item) => MoneyTransaction.fromJson(item)).toList();
      plans = workouts.map((item) => WorkoutPlan.fromJson(item)).toList();
    } catch (_) {
      events = <AgendaEvent>[];
      meals = <Meal>[];
      finance = <MoneyTransaction>[];
      plans = <WorkoutPlan>[];
    }
    if (mounted) setState(() => loading = false);
  }

  double _foodTotal(List<Meal> values, String field) {
    double total = 0;
    for (final item in values) {
      if (field == 'calories') total += item.calories;
      if (field == 'protein') total += item.protein;
      if (field == 'carbs') total += item.carbs;
      if (field == 'fat') total += item.fat;
    }
    return total;
  }

  double _moneyTotal(bool income) {
    double total = 0;
    for (final item in finance) {
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
    final calories = _foodTotal(todayMeals, 'calories');
    final protein = _foodTotal(todayMeals, 'protein');
    final carbs = _foodTotal(todayMeals, 'carbs');
    final fat = _foodTotal(todayMeals, 'fat');
    final monthKey = DateFormat('yyyy-MM').format(now);
    final monthMoney = finance.where((item) => item.date.startsWith(monthKey)).toList();
    double monthIncome = 0;
    double monthExpense = 0;
    for (final item in monthMoney) {
      if (item.income) {
        monthIncome += item.amount;
      } else {
        monthExpense += item.amount;
      }
    }
    final balance = _moneyTotal(true) - _moneyTotal(false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Olá! 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(now)),
          const SizedBox(height: 16),
          _card(
            'Resumo de hoje',
            Row(
              children: <Widget>[
                _counter(Icons.event_outlined, 'Agenda', todayEvents.length.toString()),
                _counter(Icons.fitness_center, 'Treinos', todayPlans.length.toString()),
                _counter(Icons.restaurant_outlined, 'Refeições', todayMeals.length.toString()),
              ],
            ),
          ),
          _card(
            'Próximo compromisso',
            todayEvents.isEmpty
                ? const Text('Nada agendado para hoje.')
                : ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.event)),
                    title: Text(todayEvents.first.title),
                    subtitle: Text('${todayEvents.first.start} • ${todayEvents.first.end}'),
                  ),
          ),
          _card(
            'Alimentação de hoje',
            Row(
              children: <Widget>[
                _stat(calories.toStringAsFixed(0), 'kcal'),
                _stat('${protein.toStringAsFixed(0)}g', 'proteína'),
                _stat('${carbs.toStringAsFixed(0)}g', 'carbo'),
                _stat('${fat.toStringAsFixed(0)}g', 'gordura'),
              ],
            ),
          ),
          _card(
            'Financeiro do mês',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _stat('R$ ${monthIncome.toStringAsFixed(0)}', 'entradas'),
                    _stat('R$ ${monthExpense.toStringAsFixed(0)}', 'despesas'),
                    _stat('R$ ${(monthIncome - monthExpense).toStringAsFixed(0)}', 'resultado'),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Saldo atual: R$ ${balance.toStringAsFixed(2)}'),
              ],
            ),
          ),
          if (todayPlans.isNotEmpty)
            _card(
              'Treinos de hoje',
              Column(
                children: todayPlans.map((plan) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
                    title: Text(plan.name),
                    subtitle: Text('${plan.exercisesFor(now.weekday).length} exercícios'),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _counter(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Icon(icon),
          const SizedBox(height: 5),
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
