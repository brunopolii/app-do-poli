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
    loadData();
  }

  Future<void> loadData() async {
    try {
      final agendaData = await StorageService.read('agenda');
      final mealData = await StorageService.read('meals');
      final financeData = await StorageService.read('finance');
      final workoutData = await StorageService.read('workout_plans');

      final loadedEvents = <AgendaEvent>[];
      final loadedMeals = <Meal>[];
      final loadedFinance = <MoneyTransaction>[];
      final loadedPlans = <WorkoutPlan>[];

      for (final item in agendaData) {
        loadedEvents.add(AgendaEvent.fromJson(item));
      }
      for (final item in mealData) {
        loadedMeals.add(Meal.fromJson(item));
      }
      for (final item in financeData) {
        loadedFinance.add(MoneyTransaction.fromJson(item));
      }
      for (final item in workoutData) {
        loadedPlans.add(WorkoutPlan.fromJson(item));
      }

      events = loadedEvents;
      meals = loadedMeals;
      finance = loadedFinance;
      plans = loadedPlans;
    } catch (_) {
      events = <AgendaEvent>[];
      meals = <Meal>[];
      finance = <MoneyTransaction>[];
      plans = <WorkoutPlan>[];
    }

    if (!mounted) return;
    setState(() {
      loading = false;
    });
  }

  double foodTotal(List<Meal> list, String type) {
    double total = 0;
    for (final item in list) {
      if (type == 'calories') total += item.calories;
      if (type == 'protein') total += item.protein;
      if (type == 'carbs') total += item.carbs;
      if (type == 'fat') total += item.fat;
    }
    return total;
  }

  double moneyTotal(bool income) {
    double total = 0;
    for (final item in finance) {
      if (item.income == income) total += item.amount;
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
    final monthKey = DateFormat('yyyy-MM').format(now);

    final todayEvents = <AgendaEvent>[];
    final todayMeals = <Meal>[];
    final todayPlans = <WorkoutPlan>[];
    double monthIncome = 0;
    double monthExpense = 0;

    for (final item in events) {
      if (item.date == today) todayEvents.add(item);
    }
    todayEvents.sort((a, b) => a.start.compareTo(b.start));

    for (final item in meals) {
      if (item.date == today) todayMeals.add(item);
    }

    for (final item in plans) {
      if (item.weekdays.contains(now.weekday)) todayPlans.add(item);
    }

    for (final item in finance) {
      if (item.date.startsWith(monthKey)) {
        if (item.income) {
          monthIncome += item.amount;
        } else {
          monthExpense += item.amount;
        }
      }
    }

    final calories = foodTotal(todayMeals, 'calories');
    final protein = foodTotal(todayMeals, 'protein');
    final carbs = foodTotal(todayMeals, 'carbs');
    final fat = foodTotal(todayMeals, 'fat');
    final balance = moneyTotal(true) - moneyTotal(false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Olá! 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(now)),
          const SizedBox(height: 16),
          buildCard(
            context,
            'Resumo de hoje',
            Row(
              children: <Widget>[
                buildCounter(Icons.event_outlined, 'Agenda', todayEvents.length.toString()),
                buildCounter(Icons.fitness_center, 'Treinos', todayPlans.length.toString()),
                buildCounter(Icons.restaurant_outlined, 'Refeições', todayMeals.length.toString()),
              ],
            ),
          ),
          buildCard(
            context,
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
          buildCard(
            context,
            'Alimentação de hoje',
            Row(
              children: <Widget>[
                buildStat(calories.toStringAsFixed(0), 'kcal'),
                buildStat('${protein.toStringAsFixed(0)}g', 'proteína'),
                buildStat('${carbs.toStringAsFixed(0)}g', 'carbo'),
                buildStat('${fat.toStringAsFixed(0)}g', 'gordura'),
              ],
            ),
          ),
          buildCard(
            context,
            'Financeiro do mês',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    buildStat('R$ ${monthIncome.toStringAsFixed(0)}', 'entradas'),
                    buildStat('R$ ${monthExpense.toStringAsFixed(0)}', 'despesas'),
                    buildStat('R$ ${(monthIncome - monthExpense).toStringAsFixed(0)}', 'resultado'),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Saldo atual: R$ ${balance.toStringAsFixed(2)}'),
              ],
            ),
          ),
          if (todayPlans.isNotEmpty)
            buildCard(
              context,
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

  Widget buildCard(BuildContext context, String title, Widget child) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget buildCounter(IconData icon, String label, String value) {
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

  Widget buildStat(String value, String label) {
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
