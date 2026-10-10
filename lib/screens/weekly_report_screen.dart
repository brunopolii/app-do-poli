import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  List<Workout> workouts = [];
  List<Meal> meals = [];
  List<MoneyTransaction> money = [];
  bool loading = true;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _inRange(String value, DateTime start, DateTime end) {
    final date = DateTime.tryParse(value);
    return date != null && !_day(date).isBefore(start) && !_day(date).isAfter(end);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = (await StorageService.read('workout_history')).map(Workout.fromJson).toList();
    final m = (await StorageService.read('meals')).map(Meal.fromJson).toList();
    final f = (await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList();
    if (!mounted) return;
    setState(() { workouts = w; meals = m; money = f; loading = false; });
  }

  double _sumMeals(List<Meal> source, DateTime start, DateTime end, int metric) {
    return source.where((m) => _inRange(m.date, start, end)).fold(0.0, (sum, m) =>
      sum + (metric == 0 ? m.calories : metric == 1 ? m.protein : metric == 2 ? m.carbs : m.fat));
  }

  double _sumMoney(List<MoneyTransaction> source, DateTime start, DateTime end, bool income) {
    return source.where((m) => m.income == income && m.isPaid && !m.isCancelled && _inRange(m.paidDate?.isNotEmpty == true ? m.paidDate! : m.date, start, end))
      .fold(0.0, (sum, m) => sum + m.amount);
  }

  String _money(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  String _delta(double current, double previous, {bool reverse = false}) {
    final diff = current - previous;
    final sign = diff > 0 ? '+' : '';
    final percentage = previous == 0 ? (current == 0 ? '0%' : 'novo') : '${(diff / previous * 100).toStringAsFixed(0)}%';
    return '${sign}${diff.toStringAsFixed(0)} ($percentage)';
  }

  Widget _metric(String title, String current, String previous, String delta, {bool reverse = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('Esta semana: $current'),
            Text('Semana anterior: $previous', style: Theme.of(context).textTheme.bodySmall),
          ])),
          const SizedBox(width: 8),
          Text(delta, style: TextStyle(fontWeight: FontWeight.bold, color: delta.startsWith('-') ? (reverse ? Colors.green : Colors.red) : (reverse ? Colors.red : Colors.green))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final today = _day(DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    final previousStart = start.subtract(const Duration(days: 7));
    final previousEnd = start.subtract(const Duration(days: 1));
    final currentWorkouts = workouts.where((w) => _inRange(w.date, start, today)).length.toDouble();
    final previousWorkouts = workouts.where((w) => _inRange(w.date, previousStart, previousEnd)).length.toDouble();
    final currentMeals = meals.where((m) => _inRange(m.date, start, today)).length.toDouble();
    final previousMeals = meals.where((m) => _inRange(m.date, previousStart, previousEnd)).length.toDouble();
    final currentCalories = _sumMeals(meals, start, today, 0);
    final previousCalories = _sumMeals(meals, previousStart, previousEnd, 0);
    final currentIncome = _sumMoney(money, start, today, true);
    final previousIncome = _sumMoney(money, previousStart, previousEnd, true);
    final currentExpense = _sumMoney(money, start, today, false);
    final previousExpense = _sumMoney(money, previousStart, previousEnd, false);
    final fmt = DateFormat('dd/MM');
    final period = '${fmt.format(start)} – ${fmt.format(today)}';
    final previousPeriod = '${fmt.format(previousStart)} – ${fmt.format(previousEnd)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório semanal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(period, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('Comparado com $previousPeriod', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            const Text('Resumo dos registros dos últimos 7 dias. Dados que não foram registrados não são estimados.'),
          ])),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Academia', style: Theme.of(context).textTheme.titleLarge),
            _metric('Treinos concluídos', currentWorkouts.toStringAsFixed(0), previousWorkouts.toStringAsFixed(0), _delta(currentWorkouts, previousWorkouts)),
          ])),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Alimentação', style: Theme.of(context).textTheme.titleLarge),
            _metric('Refeições registradas', currentMeals.toStringAsFixed(0), previousMeals.toStringAsFixed(0), _delta(currentMeals, previousMeals)),
            _metric('Calorias registradas', currentCalories.toStringAsFixed(0), previousCalories.toStringAsFixed(0), _delta(currentCalories, previousCalories)),
            _metric('Proteína', '${_sumMeals(meals, start, today, 1).toStringAsFixed(0)} g', '${_sumMeals(meals, previousStart, previousEnd, 1).toStringAsFixed(0)} g', _delta(_sumMeals(meals, start, today, 1), _sumMeals(meals, previousStart, previousEnd, 1))),
          ])),
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Financeiro', style: Theme.of(context).textTheme.titleLarge),
            _metric('Entradas recebidas', _money(currentIncome), _money(previousIncome), _delta(currentIncome, previousIncome)),
            _metric('Despesas pagas', _money(currentExpense), _money(previousExpense), _delta(currentExpense, previousExpense, reverse: true), reverse: true),
            _metric('Resultado', _money(currentIncome - currentExpense), _money(previousIncome - previousExpense), _delta(currentIncome - currentExpense, previousIncome - previousExpense)),
          ])),
        ],
      ),
    );
  }
}
