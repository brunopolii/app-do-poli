import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/ai_food_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});
  @override State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final AiFoodService ai = AiFoodService();
  final ImagePicker picker = ImagePicker();
  List<Meal> meals = <Meal>[];
  List<WeightEntry> weights = <WeightEntry>[];
  Map<String, double>? goals;
  bool loading = true;

  String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      meals = (await StorageService.read('meals')).map(Meal.fromJson).toList();
      weights = (await StorageService.read('body_weights')).map(WeightEntry.fromJson).toList();
      weights.sort((a, b) => a.date.compareTo(b.date));
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
    } catch (_) {
      meals = <Meal>[];
      weights = <WeightEntry>[];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveMeals() => StorageService.write('meals', meals.map((e) => e.toJson()).toList());
  Future<void> _saveWeights() => StorageService.write('body_weights', weights.map((e) => e.toJson()).toList());

  Future<void> _saveWeight(double value) async {
    weights.removeWhere((e) => e.date == today);
    weights.add(WeightEntry(date: today, weight: value));
    weights.sort((a, b) => a.date.compareTo(b.date));
    await _saveWeights();
  }

  Future<void> _setupGoals() async {
    final age = TextEditingController();
    final weight = TextEditingController();
    final height = TextEditingController();
    String sex = 'Masculino';
    String activity = 'Moderado';
    String objective = 'Manter peso';

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Metas nutricionais'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Idade')),
            TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso (kg)')),
            TextField(controller: height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Altura (cm)')),
            DropdownButtonFormField<String>(initialValue: sex, items: const ['Masculino', 'Feminino'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setDialog(() => sex = v); }, decoration: const InputDecoration(labelText: 'Sexo')),
            DropdownButtonFormField<String>(initialValue: activity, items: const ['Sedentário', 'Levemente ativo', 'Moderado', 'Muito ativo', 'Extremamente ativo'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setDialog(() => activity = v); }, decoration: const InputDecoration(labelText: 'Atividade')),
            DropdownButtonFormField<String>(initialValue: objective, items: const ['Perder peso', 'Manter peso', 'Ganhar peso'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setDialog(() => objective = v); }, decoration: const InputDecoration(labelText: 'Objetivo')),
            const SizedBox(height: 8),
            const Text('Valores estimados; não substituem orientação profissional.', style: TextStyle(fontSize: 12)),
          ])),
          actions: <Widget>[FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Calcular'))],
        ),
      ),
    );
    final a = double.tryParse(age.text.replaceAll(',', '.'));
    final w = double.tryParse(weight.text.replaceAll(',', '.'));
    final h = double.tryParse(height.text.replaceAll(',', '.'));
    if (ok != true || a == null || w == null || h == null || a <= 0 || w <= 0 || h <= 0) return;

    const factors = <String, double>{
      'Sedentário': 1.2, 'Levemente ativo': 1.375, 'Moderado': 1.55,
      'Muito ativo': 1.725, 'Extremamente ativo': 1.9,
    };
    final bmr = sex == 'Masculino' ? 10 * w + 6.25 * h - 5 * a + 5 : 10 * w + 6.25 * h - 5 * a - 161;
    final kcal = bmr * factors[activity]! + (objective == 'Perder peso' ? -400 : objective == 'Ganhar peso' ? 300 : 0);
    goals = <String, double>{
      'calories': kcal,
      'protein': w * 2,
      'fat': kcal * 0.27 / 9,
      'carbs': (kcal - w * 2 * 4 - kcal * 0.27) / 4,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nutrition_goals', '${goals!['calories']}|${goals!['protein']}|${goals!['carbs']}|${goals!['fat']}');
    await _saveWeight(w);
    if (mounted) setState(() {});
  }

  Future<void> _weight() async {
    final controller = TextEditingController();
    final existing = weights.where((e) => e.date == today).toList();
    if (existing.isNotEmpty) controller.text = existing.first.weight.toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Peso de hoje'),
        content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'kg')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
        ],
      ),
    );
    final value = double.tryParse(controller.text.replaceAll(',', '.'));
    if (ok != true || value == null || value <= 0) return;
    await _saveWeight(value);
    if (mounted) setState(() {});
  }

  Future<void> _manual() async {
    final name = TextEditingController();
    final quantity = TextEditingController();
    final kcal = TextEditingController();
    final protein = TextEditingController();
    final carbs = TextEditingController();
    final fat = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar alimento'),
        content: SingleChildScrollView(child: Column(children: <Widget>[
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Alimento')),
          TextField(controller: quantity, decoration: const InputDecoration(labelText: 'Quantidade / peso')),
          TextField(controller: kcal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Calorias')),
          TextField(controller: protein, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Proteína (g)')),
          TextField(controller: carbs, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Carboidratos (g)')),
          TextField(controller: fat, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Gorduras (g)')),
        ])),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Adicionar')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    meals.add(Meal(
      id: DateTime.now().microsecondsSinceEpoch.toString(), date: today, type: 'Refeição',
      food: quantity.text.trim().isEmpty ? name.text.trim() : '${name.text.trim()} (${quantity.text.trim()})',
      calories: double.tryParse(kcal.text.replaceAll(',', '.')) ?? 0,
      protein: double.tryParse(protein.text.replaceAll(',', '.')) ?? 0,
      carbs: double.tryParse(carbs.text.replaceAll(',', '.')) ?? 0,
      fat: double.tryParse(fat.text.replaceAll(',', '.')) ?? 0,
    ));
    await _saveMeals();
    if (mounted) setState(() {});
  }

  Future<void> _textAI() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Analisar por texto'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Ex.: 200g arroz, 150g frango e 2 ovos')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Analisar')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      final result = await ai.estimateText(controller.text);
      if (mounted) await _result(result);
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  Future<void> _photo() async {
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) return;
    try {
      final result = await ai.estimateImage(image.path);
      if (mounted) await _result(result);
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  Future<void> _result(FoodResult result) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Estimativa nutricional'),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          for (final item in result.items) ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.name),
            subtitle: Text('${item.grams.toStringAsFixed(0)}g • ${item.calories.toStringAsFixed(0)} kcal • P ${item.protein.toStringAsFixed(1)}g • C ${item.carbs.toStringAsFixed(1)}g • G ${item.fat.toStringAsFixed(1)}g'),
          ),
          const Divider(),
          Text('${result.calories.toStringAsFixed(0)} kcal • P ${result.protein.toStringAsFixed(1)}g • C ${result.carbs.toStringAsFixed(1)}g • G ${result.fat.toStringAsFixed(1)}g'),
          const SizedBox(height: 8),
          Text(result.note),
        ])),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('NÃO CONTAR')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('CONTAR')),
        ],
      ),
    );
    if (ok != true || result.items.every((e) => e.calories == 0 && e.grams == 0)) return;
    meals.add(Meal(
      id: DateTime.now().microsecondsSinceEpoch.toString(), date: today, type: 'Refeição',
      food: result.items.map((e) => e.name).join(', '), calories: result.calories,
      protein: result.protein, carbs: result.carbs, fat: result.fat, source: 'ai',
    ));
    await _saveMeals();
    if (mounted) setState(() {});
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  List<double> _dailyCalories() {
    final now = DateTime.now();
    return List<double>.generate(7, (index) {
      final date = DateTime(now.year, now.month, now.day - (6 - index));
      final key = DateFormat('yyyy-MM-dd').format(date);
      return meals.where((meal) => meal.date == key).fold<double>(0.0, (sum, meal) => sum + meal.calories);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final todayMeals = meals.where((meal) => meal.date == today).toList();
    final kcal = todayMeals.fold<double>(0.0, (sum, meal) => sum + meal.calories);
    final protein = todayMeals.fold<double>(0.0, (sum, meal) => sum + meal.protein);
    final carbs = todayMeals.fold<double>(0.0, (sum, meal) => sum + meal.carbs);
    final fat = todayMeals.fold<double>(0.0, (sum, meal) => sum + meal.fat);
    final currentWeight = weights.isEmpty ? null : weights.last;
    final days = _dailyCalories();

    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: <Widget>[
      Row(children: <Widget>[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('Alimentação', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('${todayMeals.length} refeição(ões) hoje'),
        ])),
        IconButton(onPressed: _setupGoals, icon: const Icon(Icons.settings_outlined)),
      ]),
      if (goals != null) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('Metas diárias', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        _bar('Calorias', kcal, goals!['calories']!, 'kcal'),
        _bar('Proteína', protein, goals!['protein']!, 'g'),
        _bar('Carboidratos', carbs, goals!['carbs']!, 'g'),
        _bar('Gorduras', fat, goals!['fat']!, 'g'),
      ])),
      AppCard(child: Row(children: <Widget>[
        const Icon(Icons.monitor_weight_outlined, size: 32), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('Peso corporal'),
          Text(currentWeight == null ? '—' : '${currentWeight.weight.toStringAsFixed(1)} kg', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ])),
        OutlinedButton(onPressed: _weight, child: const Text('Registrar')),
      ])),
      if (weights.length > 1) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('Evolução do peso', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(height: 100, child: WeightChart(weights: weights)),
      ])),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('Calorias por dia', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(height: 150, child: DailyCaloriesChart(values: days)),
        const SizedBox(height: 6),
        Row(children: List<Widget>.generate(7, (index) {
          final date = DateTime.now().subtract(Duration(days: 6 - index));
          return Expanded(child: Text(DateFormat('dd/MM').format(date), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall));
        })),
      ])),
      Row(children: <Widget>[
        Expanded(child: FilledButton.icon(onPressed: _textAI, icon: const Icon(Icons.auto_awesome), label: const Text('Analisar texto'))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _photo, icon: const Icon(Icons.camera_alt_outlined)),
      ]),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(onPressed: _manual, icon: const Icon(Icons.add), label: const Text('Adicionar manualmente')),
      const SizedBox(height: 16),
      Text('Refeições de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      if (todayMeals.isEmpty) const AppCard(child: Text('Nenhuma refeição registrada.')),
      ...todayMeals.map((meal) => AppCard(child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(meal.food),
        subtitle: Text('${meal.calories.toStringAsFixed(0)} kcal • P ${meal.protein.toStringAsFixed(1)}g • C ${meal.carbs.toStringAsFixed(1)}g • G ${meal.fat.toStringAsFixed(1)}g'),
        trailing: IconButton(onPressed: () async { meals.remove(meal); await _saveMeals(); if (mounted) setState(() {}); }, icon: const Icon(Icons.delete_outline)),
      ))),
    ]));
  }

  Widget _bar(String name, double value, double goal, String unit) {
    final progress = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0).toDouble();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[Expanded(child: Text(name)), Text('${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit')]),
      const SizedBox(height: 4),
      LinearProgressIndicator(value: progress, minHeight: 7),
    ]));
  }
}

class WeightChart extends StatelessWidget {
  final List<WeightEntry> weights;
  const WeightChart({super.key, required this.weights});
  @override Widget build(BuildContext context) {
    final visible = weights.length > 12 ? weights.sublist(weights.length - 12) : weights;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: visible.map((entry) {
      final min = visible.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
      final max = visible.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
      final ratio = max == min ? 0.5 : (entry.weight - min) / (max - min);
      return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
        Text(entry.weight.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
        const SizedBox(height: 4),
        Container(height: 12 + ratio * 58, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(5))),
      ])));
    }).toList());
  }
}

class DailyCaloriesChart extends StatelessWidget {
  final List<double> values;
  const DailyCaloriesChart({super.key, required this.values});
  @override Widget build(BuildContext context) {
    return CustomPaint(painter: _DailyCaloriesPainter(values, Theme.of(context).colorScheme.primary), size: const Size(double.infinity, 150));
  }
}

class _DailyCaloriesPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _DailyCaloriesPainter(this.values, this.color);
  @override void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<double>(1.0, (max, value) => value > max ? value : max);
    final slot = size.width / values.length;
    final barWidth = slot * 0.55;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final height = values[i] / maxValue * (size.height - 20);
      final x = i * slot + (slot - barWidth) / 2;
      final y = size.height - height - 4;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, height), const Radius.circular(7)), paint);
    }
  }
  @override bool shouldRepaint(covariant _DailyCaloriesPainter oldDelegate) => oldDelegate.values != values || oldDelegate.color != color;
}
