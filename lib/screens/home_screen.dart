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
  List<AgendaEvent> events = [];
  List<Meal> meals = [];
  List<MoneyTransaction> finance = [];
  List<WorkoutPlan> plans = [];
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
      final p = raw.split('|');
      if (p.length == 4) {
        goals = {'calories': double.tryParse(p[0]) ?? 0, 'protein': double.tryParse(p[1]) ?? 0, 'carbs': double.tryParse(p[2]) ?? 0, 'fat': double.tryParse(p[3]) ?? 0};
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final todayEvents = events.where((e) => e.date == today).toList()..sort((a,b) => a.start.compareTo(b.start));
    final todayMeals = meals.where((e) => e.date == today).toList();
    final todayPlans = plans.where((p) => p.weekdays.contains(now.weekday)).toList();
    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (final meal in todayMeals) { calories += meal.calories; protein += meal.protein; carbs += meal.carbs; fat += meal.fat; }
    double income = 0, expense = 0;
    final monthKey = DateFormat('yyyy-MM').format(now);
    for (final item in finance.where((e) => e.date.startsWith(monthKey))) { if (item.income) income += item.amount; else expense += item.amount; }
    double balance = 0;
    for (final item in finance) { balance += item.income ? item.amount : -item.amount; }

    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16,16,16,32), children: [
      Text('Olá! 👋', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(now)),
      const SizedBox(height: 16),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Resumo de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Row(children: [_counter(Icons.event_outlined, 'Agenda', todayEvents.length), _counter(Icons.fitness_center, 'Treinos', todayPlans.length), _counter(Icons.restaurant_outlined, 'Refeições', todayMeals.length)]),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Próximo compromisso', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (todayEvents.isEmpty) const Text('Nada agendado para hoje.') else ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.event)), title: Text(todayEvents.first.title), subtitle: Text('${todayEvents.first.start} • ${todayEvents.first.end}')),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Alimentação de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [_stat('${calories.toStringAsFixed(0)}', 'kcal'), _stat('${protein.toStringAsFixed(0)}g', 'proteína'), _stat('${carbs.toStringAsFixed(0)}g', 'carbo'), _stat('${fat.toStringAsFixed(0)}g', 'gordura')]),
        if (goals != null) ...[const SizedBox(height: 12), LinearProgressIndicator(value: goals!['calories']! <= 0 ? 0 : (calories / goals!['calories']!).clamp(0.0,1.0).toDouble()), const SizedBox(height: 5), Text('Meta: ${goals!['calories']!.toStringAsFixed(0)} kcal')],
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Financeiro do mês', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [_stat('R$ ${income.toStringAsFixed(0)}', 'entradas'), _stat('R$ ${expense.toStringAsFixed(0)}', 'despesas'), _stat('R$ ${(income-expense).toStringAsFixed(0)}', 'resultado')]),
        const SizedBox(height: 10), Text('Saldo atual: R$ ${balance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ])),
      if (todayPlans.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Treinos de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), ...todayPlans.map((p) => ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.fitness_center)), title: Text(p.name), subtitle: Text('${p.exercisesFor(now.weekday).length} exercícios')))])),
    ]));
  }

  Widget _counter(IconData icon, String label, int value) => Expanded(child: Column(children: [Icon(icon), const SizedBox(height: 5), Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)), Text(label)]));
  Widget _stat(String value, String label) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), Text(label, style: Theme.of(context).textTheme.bodySmall)]));
}
