import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AgendaEvent> events = <AgendaEvent>[];
  List<Meal> meals = <Meal>[];
  List<MoneyTransaction> finance = <MoneyTransaction>[];
  List<WorkoutPlan> plans = <WorkoutPlan>[];
  Map<String, double>? goals;
  bool loading = true;

  String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    events = (await StorageService.read('agenda')).map(AgendaEvent.fromJson).toList();
    meals = (await StorageService.read('meals')).map(Meal.fromJson).toList();
    finance = (await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList();
    plans = (await StorageService.read('workout_plans')).map(WorkoutPlan.fromJson).toList();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nutrition_goals');
    if (raw != null) {
      final parts = raw.split('|');
      if (parts.length == 4) {
        goals = <String, double>{
          'calories': double.tryParse(parts[0]) ?? 0,
          'protein': double.tryParse(parts[1]) ?? 0,
          'carbs': double.tryParse(parts[2]) ?? 0,
          'fat': double.tryParse(parts[3]) ?? 0,
        };
      }
    }
    if (mounted) setState(() => loading = false);
  }

  double _sumMeals(double Function(Meal) value, List<Meal> list) {
    double total = 0;
    for (final meal in list) total += value(meal);
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final dayEvents = events.where((e) => e.date == today).toList();
    dayEvents.sort((a, b) => a.start.compareTo(b.start));
    final dayMeals = meals.where((e) => e.date == today).toList();
    final dayPlans = plans.where((p) => p.weekdays.contains(now.weekday)).toList();
    final calories = _sumMeals((m) => m.calories, dayMeals);
    final protein = _sumMeals((m) => m.protein, dayMeals);
    final carbs = _sumMeals((m) => m.carbs, dayMeals);
    final fat = _sumMeals((m) => m.fat, dayMeals);
    final monthKey = DateFormat('yyyy-MM').format(now);
    final monthTransactions = finance.where((e) => e.date.startsWith(monthKey)).toList();
    final income = _sumFinance(monthTransactions, true);
    final expense = _sumFinance(monthTransactions, false);
    final balance = _sumFinance(finance, true) - _sumFinance(finance, false);

    final children = <Widget>[];
    children.add(Text('Olá! 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)));
    children.add(Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(now)));
    children.add(const SizedBox(height: 16));
    children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('Resumo de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Row(children: <Widget>[
        _counter(Icons.event_outlined, 'Agenda', '${dayEvents.length}'),
        _counter(Icons.fitness_center, 'Treinos', '${dayPlans.length}'),
        _counter(Icons.restaurant_outlined, 'Refeições', '${dayMeals.length}'),
      ]),
    ])));
    children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('Próximo compromisso', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (dayEvents.isEmpty) const Text('Nada agendado para hoje.') else ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.event)),
        title: Text(dayEvents.first.title),
        subtitle: Text('${dayEvents.first.start} • ${dayEvents.first.end}'),
      ),
    ])));
    children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('Alimentação de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Row(children: <Widget>[
        _stat('${calories.toStringAsFixed(0)}', 'kcal'),
        _stat('${protein.toStringAsFixed(0)}g', 'proteína'),
        _stat('${carbs.toStringAsFixed(0)}g', 'carbo'),
        _stat('${fat.toStringAsFixed(0)}g', 'gordura'),
      ]),
      if (goals != null) ...<Widget>[
        const SizedBox(height: 12),
        LinearProgressIndicator(value: goals!['calories']! <= 0 ? 0 : (calories / goals!['calories']!).clamp(0.0, 1.0).toDouble(), minHeight: 8),
        const SizedBox(height: 5),
        Text('Meta: ${goals!['calories']!.toStringAsFixed(0)} kcal'),
      ],
    ])));
    children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('Financeiro do mês', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      Row(children: <Widget>[
        _stat('R$ ${income.toStringAsFixed(0)}', 'entradas'),
        _stat('R$ ${expense.toStringAsFixed(0)}', 'despesas'),
        _stat('R$ ${(income - expense).toStringAsFixed(0)}', 'resultado'),
      ]),
      const SizedBox(height: 10),
      Text('Saldo atual: R$ ${balance.toStringAsFixed(2)}'),
    ])));
    if (dayPlans.isNotEmpty) {
      final workoutChildren = <Widget>[];
      workoutChildren.add(Text('Treinos de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)));
      for (final plan in dayPlans) {
        workoutChildren.add(ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
          title: Text(plan.name),
          subtitle: Text('${plan.exercisesFor(now.weekday).length} exercícios'),
        ));
      }
      children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: workoutChildren)));
    }
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: children));
  }

  double _sumFinance(Iterable<MoneyTransaction> list, bool income) {
    double total = 0;
    for (final item in list) { if (item.income == income) total += item.amount; }
    return total;
  }

  Widget _counter(IconData icon, String label, String value) {
    return Expanded(child: Column(children: <Widget>[
      Icon(icon), const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]));
  }

  Widget _stat(String value, String label) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
}
