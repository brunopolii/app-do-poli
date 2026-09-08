import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class GymHistorySection extends StatefulWidget {
  const GymHistorySection({super.key});
  @override State<GymHistorySection> createState() => _GymHistorySectionState();
}

class _GymHistorySectionState extends State<GymHistorySection> {
  List<Workout> history = [];
  String? selectedPlan;
  int? selectedDay;
  String? selectedExercise;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final raw = await StorageService.read('workout_history');
    history = raw.map(Workout.fromJson).toList();
    history.sort((a, b) => a.date.compareTo(b.date));
    if (mounted) setState(() {});
  }

  List<String> get planNames => history.map((w) => w.name).toSet().toList()..sort();
  List<Workout> get matchingWorkouts => history.where((w) => (selectedPlan == null || w.name == selectedPlan) && (selectedDay == null || w.weekday == selectedDay)).toList();
  List<String> get exerciseNames => matchingWorkouts.expand((w) => w.exercises.map((e) => e.name)).toSet().toList()..sort();

  List<_Point> get points {
    if (selectedExercise == null) return [];
    final result = <_Point>[];
    for (final w in matchingWorkouts) {
      final matches = w.exercises.where((e) => e.name == selectedExercise).toList();
      if (matches.isEmpty) continue;
      final maxKg = matches.expand((e) => e.weights).fold<double>(0, math.max);
      if (maxKg > 0) result.add(_Point(DateTime.tryParse(w.date) ?? DateTime.now(), maxKg));
    }
    return result..sort((a, b) => a.date.compareTo(b.date));
  }

  @override Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    final plans = planNames;
    selectedPlan ??= plans.first;
    if (selectedPlan != null && !plans.contains(selectedPlan)) selectedPlan = plans.first;
    final days = history.where((w) => w.name == selectedPlan).map((w) => w.weekday).toSet().toList()..sort();
    selectedDay ??= days.isNotEmpty ? days.first : null;
    if (selectedDay != null && !days.contains(selectedDay)) selectedDay = days.first;
    final exercises = exerciseNames;
    if (selectedExercise == null || !exercises.contains(selectedExercise)) selectedExercise = exercises.isEmpty ? null : exercises.first;

    return AppCardLike(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.show_chart), const SizedBox(width: 8), Expanded(child: Text('Evolução dos treinos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)))]),
      const SizedBox(height: 6),
      const Text('Histórico completo, sem limite de dias. O peso de cada treino usa a maior carga das séries.'),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(value: selectedPlan, isExpanded: true, decoration: const InputDecoration(labelText: 'Treino'), items: plans.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() { selectedPlan = v; selectedDay = null; selectedExercise = null; })),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(value: selectedDay, isExpanded: true, decoration: const InputDecoration(labelText: 'Dia do treino'), items: days.map((d) => DropdownMenuItem(value: d, child: Text(_dayName(d)))).toList(), onChanged: (v) => setState(() { selectedDay = v; selectedExercise = null; })),
      const SizedBox(height: 10),
      if (exercises.isNotEmpty) DropdownButtonFormField<String>(value: selectedExercise, isExpanded: true, decoration: const InputDecoration(labelText: 'Exercício'), items: exercises.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => selectedExercise = v)),
      const SizedBox(height: 14),
      if (points.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Ainda não há cargas registradas para este exercício.')))
      else SizedBox(height: 240, child: _LineChart(points: points)),
      if (points.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${points.first.kg.toStringAsFixed(1)} kg → ${points.last.kg.toStringAsFixed(1)} kg • ${points.length} treino(s)', style: Theme.of(context).textTheme.bodySmall)),
    ]));
  }

  String _dayName(int d) => const ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'][d - 1];
}

class _Point { final DateTime date; final double kg; _Point(this.date, this.kg); }

class _LineChart extends StatelessWidget {
  final List<_Point> points;
  const _LineChart({required this.points});
  @override Widget build(BuildContext context) => CustomPaint(painter: _ChartPainter(points, Theme.of(context).colorScheme), child: const SizedBox.expand());
}

class _ChartPainter extends CustomPainter {
  final List<_Point> points; final ColorScheme scheme;
  _ChartPainter(this.points, this.scheme);
  @override void paint(Canvas canvas, Size size) {
    const pad = EdgeInsets.fromLTRB(42, 12, 12, 30);
    final rect = Rect.fromLTWH(pad.left, pad.top, math.max(1, size.width - pad.left - pad.right), math.max(1, size.height - pad.top - pad.bottom));
    final values = points.map((p) => p.kg).toList();
    var minV = values.reduce(math.min); var maxV = values.reduce(math.max);
    if ((maxV - minV).abs() < 0.01) { minV -= 1; maxV += 1; } else { final extra = (maxV - minV) * .12; minV -= extra; maxV += extra; }
    final grid = Paint()..color = scheme.outlineVariant.withOpacity(.45)..strokeWidth = 1;
    final line = Paint()..color = scheme.primary..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final dot = Paint()..color = scheme.primary;
    for (var i = 0; i <= 4; i++) { final y = rect.bottom - rect.height * i / 4; canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid); final value = minV + (maxV - minV) * i / 4; _text(canvas, '${value.toStringAsFixed(1)} kg', Offset(0, y - 8), 11, scheme.onSurfaceVariant); }
    final path = Path();
    for (var i = 0; i < points.length; i++) { final x = points.length == 1 ? rect.center.dx : rect.left + rect.width * i / (points.length - 1); final y = rect.bottom - ((points[i].kg - minV) / (maxV - minV)) * rect.height; if (i == 0) path.moveTo(x, y); else path.lineTo(x, y); canvas.drawCircle(Offset(x, y), 4, dot); if (i == 0 || i == points.length - 1) _text(canvas, _date(points[i].date), Offset(x - 22, rect.bottom + 8), 10, scheme.onSurfaceVariant); }
    canvas.drawPath(path, line);
  }
  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  void _text(Canvas c, String s, Offset p, double size, Color color) { final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color)), textDirection: TextDirection.ltr)..layout(); tp.paint(c, p); }
  @override bool shouldRepaint(covariant _ChartPainter old) => old.points != points || old.scheme != scheme;
}

class AppCardLike extends StatelessWidget {
  final Widget child;
  const AppCardLike({super.key, required this.child});
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 16), child: Padding(padding: const EdgeInsets.all(16), child: child));
}
