import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class GymHistorySection extends StatefulWidget {
  const GymHistorySection({super.key});
  @override
  State<GymHistorySection> createState() => _GymHistorySectionState();
}

class _GymHistorySectionState extends State<GymHistorySection> {
  List<Workout> history = [];
  String? selectedPlan;
  int? selectedDay;
  String? selectedExercise;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.read('workout_history');
    history = raw.map((e) => Workout.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    history.sort((a, b) => a.date.compareTo(b.date));
    if (mounted) setState(() {});
  }

  List<String> get planNames => history.map((w) => w.name).toSet().toList()..sort();

  List<Workout> get matchingWorkouts => history.where((w) {
        return (selectedPlan == null || w.name == selectedPlan) &&
            (selectedDay == null || w.weekday == selectedDay);
      }).toList();

  List<String> get exerciseNames => matchingWorkouts
      .expand((w) => w.exercises.map((e) => e.name))
      .toSet()
      .toList()
    ..sort();

  List<_Point> get points {
    if (selectedExercise == null) return [];
    final result = <_Point>[];
    for (final workout in matchingWorkouts) {
      final exercises = workout.exercises.where((e) => e.name == selectedExercise);
      double maxKg = 0;
      for (final exercise in exercises) {
        for (final weight in exercise.weights) {
          if (weight > maxKg) maxKg = weight;
        }
      }
      if (maxKg > 0) {
        final date = DateTime.tryParse(workout.date);
        if (date != null) result.add(_Point(date, maxKg));
      }
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    final plans = planNames;
    selectedPlan ??= plans.isNotEmpty ? plans.first : null;
    if (selectedPlan != null && !plans.contains(selectedPlan)) {
      selectedPlan = plans.first;
    }

    final days = history
        .where((w) => w.name == selectedPlan)
        .map((w) => w.weekday)
        .where((d) => d >= 1 && d <= 7)
        .toSet()
        .toList()
      ..sort();
    selectedDay ??= days.isNotEmpty ? days.first : null;
    if (selectedDay != null && !days.contains(selectedDay)) {
      selectedDay = days.isNotEmpty ? days.first : null;
    }

    final exercises = exerciseNames;
    if (selectedExercise == null || !exercises.contains(selectedExercise)) {
      selectedExercise = exercises.isNotEmpty ? exercises.first : null;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Evolução dos treinos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Histórico completo, sem limite de dias. O peso mostrado é a maior carga usada no exercício em cada treino.'),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: selectedPlan,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Treino'),
              items: plans.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() {
                selectedPlan = value;
                selectedDay = null;
                selectedExercise = null;
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: selectedDay,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Dia do treino'),
              items: days.map((d) => DropdownMenuItem(value: d, child: Text(_dayName(d)))).toList(),
              onChanged: (value) => setState(() {
                selectedDay = value;
                selectedExercise = null;
              }),
            ),
            if (exercises.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedExercise,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Exercício'),
                items: exercises.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setState(() => selectedExercise = value),
              ),
            ],
            const SizedBox(height: 14),
            if (points.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Ainda não há cargas registradas para este exercício.')),
              )
            else
              SizedBox(height: 240, child: _LineChart(points: points)),
            if (points.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${points.first.kg.toStringAsFixed(1)} kg → ${points.last.kg.toStringAsFixed(1)} kg • ${points.length} treino(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dayName(int day) => const [
        'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
      ][day - 1];
}

class _Point {
  final DateTime date;
  final double kg;
  const _Point(this.date, this.kg);
}

class _LineChart extends StatelessWidget {
  final List<_Point> points;
  const _LineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(points, Theme.of(context).colorScheme),
      child: const SizedBox.expand(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_Point> points;
  final ColorScheme scheme;
  _ChartPainter(this.points, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0;
    const top = 12.0;
    const right = 12.0;
    const bottom = 30.0;
    final width = math.max(1.0, size.width - left - right).toDouble();
    final height = math.max(1.0, size.height - top - bottom).toDouble();
    final rect = Rect.fromLTWH(left, top, width, height);

    var minValue = points.first.kg;
    var maxValue = points.first.kg;
    for (final point in points.skip(1)) {
      minValue = math.min(minValue, point.kg).toDouble();
      maxValue = math.max(maxValue, point.kg).toDouble();
    }
    if ((maxValue - minValue).abs() < 0.01) {
      minValue -= 1;
      maxValue += 1;
    } else {
      final extra = (maxValue - minValue) * 0.12;
      minValue -= extra;
      maxValue += extra;
    }

    final grid = Paint()
      ..color = scheme.outlineVariant.withOpacity(0.45)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = scheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = scheme.primary;

    for (var i = 0; i <= 4; i++) {
      final y = rect.bottom - rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      final value = minValue + (maxValue - minValue) * i / 4;
      _text(canvas, '${value.toStringAsFixed(1)} kg', Offset(0, y - 8), 11, scheme.onSurfaceVariant);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? rect.center.dx
          : rect.left + rect.width * i / (points.length - 1);
      final ratio = (points[i].kg - minValue) / (maxValue - minValue);
      final y = rect.bottom - ratio * rect.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dot);
      if (i == 0 || i == points.length - 1) {
        _text(canvas, _date(points[i].date), Offset(x - 22, rect.bottom + 8), 10, scheme.onSurfaceVariant);
      }
    }
    canvas.drawPath(path, line);
  }

  String _date(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  void _text(Canvas canvas, String text, Offset position, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => oldDelegate.points != points || oldDelegate.scheme != scheme;
}
