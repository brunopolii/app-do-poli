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
      events = (await StorageService.read('agenda')).map(AgendaEvent.fromJson).toList();
      meals = (await StorageService.read('meals')).map(Meal.fromJson).toList();
      finance = (await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList();
      plans = (await StorageService.read('workout_plans')).map(WorkoutPlan.fromJson).toList();
    } catch (_) {
      events = <AgendaEvent>[];
      meals = <Meal>[];
      finance = <MoneyTransaction>[];
      plans = <WorkoutPlan>[];
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  double _mealSum(List<Meal> values, double Function(Meal) selector) {
    double total = 0;
    for (final meal in values) {
      total += selector(meal);
    }
    return total;
  }

  double _financeSum(bool income, [Iterable<MoneyTransaction>? values]) {
    final source = values ?? finance;
    double total = 0;
    for (final item in source) {
      if (item.income == income) {
        total += item.amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final dayEvents = events.where((item) => item.date == today).toList();
    dayEvents.sort((a, b) => a.start.compareTo(b.start));

    final dayMeals = meals.where((item) => item.date == today).toList();
    final todayPlans = plans.where((plan) => plan.weekdays.contains(now.weekday)).toList();

    final calories = _mealSum(dayMeals, (meal) => meal.calories);
    final protein = _mealSum(dayMeals, (meal) => meal.protein);
    final carbs = _mealSum(dayMeals, (meal) => meal.carbs);
    final fat = _mealSum(dayMeals, (meal) => meal.fat);

    final monthKey = DateFormat('yyyy-MM').format(now);
    final monthFinance = finance.where((item) => item.date.startsWith(monthKey)).toList();
    final monthIncome = _financeSum(true, monthFinance);
    final monthExpense = _financeSum(false, monthFinance);
    final balance = _financeSum(true) - _financeSum(false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text(
            'Olá! 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(now)),
          const SizedBox(height: 16),
          _summaryCard(dayEvents.length, todayPlans.length, dayMeals.length),
          _agendaCard(dayEvents),
          _foodCard(calories, protein, carbs, fat),
          _financeCard(monthIncome, monthExpense, balance),
          if (todayPlans.isNotEmpty) _workoutCard(todayPlans, now.weekday),
        ],
      ),
    );
  }

  Widget _summaryCard(int agenda, int workouts, int food) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Resumo de hoje',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _counter(Icons.event_outlined, 'Agenda', agenda.toString()),
              _counter(Icons.fitness_center, 'Treinos', workouts.toString()),
              _counter(Icons.restaurant_outlined, 'Refeições', food.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _agendaCard(List<AgendaEvent> items) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Próximo compromisso',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
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

  Widget _foodCard(double calories, double protein, double carbs, double fat) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Alimentação de hoje',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _stat(calories.toStringAsFixed(0), 'kcal'),
              _stat('${protein.toStringAsFixed(0)}g', 'proteína'),
              _stat('${carbs.toStringAsFixed(0)}g', 'carbo'),
              _stat('${fat.toStringAsFixed(0)}g', 'gordura'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _financeCard(double income, double expense, double balance) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Financeiro do mês',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _stat('R$ ${income.toStringAsFixed(0)}', 'entradas'),
              _stat('R$ ${expense.toStringAsFixed(0)}', 'despesas'),
              _stat('R$ ${(income - expense).toStringAsFixed(0)}', 'resultado'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Saldo atual: R$ ${balance.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _workoutCard(List<WorkoutPlan> items, int weekday) {
    final children = <Widget>[
      Text(
        'Treinos de hoje',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
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
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
