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
  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final ai = AiFoodService();
  final picker = ImagePicker();
  List<Meal> meals = [];
  List<WeightEntry> weights = [];
  Map<String, double>? goals;
  bool loading = true;

  String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    meals = (await StorageService.read('meals')).map(Meal.fromJson).toList();
    weights = (await StorageService.read('body_weights')).map(WeightEntry.fromJson).toList();
    weights.sort((a, b) => a.date.compareTo(b.date));
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nutrition_goals');
    if (raw != null) {
      final p = raw.split('|');
      if (p.length == 4) goals = {'calories': double.tryParse(p[0]) ?? 0, 'protein': double.tryParse(p[1]) ?? 0, 'carbs': double.tryParse(p[2]) ?? 0, 'fat': double.tryParse(p[3]) ?? 0};
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveMeals() => StorageService.write('meals', meals.map((e) => e.toJson()).toList());
  Future<void> _saveWeights() => StorageService.write('body_weights', weights.map((e) => e.toJson()).toList());

  Future<void> _setup() async {
    final age = TextEditingController();
    final weight = TextEditingController();
    final height = TextEditingController();
    String sex = 'Masculino';
    String activity = 'Moderado';
    String objective = 'Manter peso';
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Metas nutricionais'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Idade')),
            TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso (kg)')),
            TextField(controller: height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Altura (cm)')),
            DropdownButtonFormField<String>(value: sex, items: ['Masculino', 'Feminino'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setDialogState(() => sex = v); }, decoration: const InputDecoration(labelText: 'Sexo')),
            DropdownButtonFormField<String>(value: activity, items: ['Sedentário', 'Levemente ativo', 'Moderado', 'Muito ativo', 'Extremamente ativo'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setDialogState(() => activity = v); }, decoration: const InputDecoration(labelText: 'Atividade')),
            DropdownButtonFormField<String>(value: objective, items: ['Perder peso', 'Manter peso', 'Ganhar peso'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setDialogState(() => objective = v); }, decoration: const InputDecoration(labelText: 'Objetivo')),
            const SizedBox(height: 8),
            const Text('Os valores são estimativas e não substituem orientação profissional.', style: TextStyle(fontSize: 12)),
          ])),
          actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Calcular'))],
        );
      }),
    );
    if (ok != true) return;
    final a = double.tryParse(age.text.replaceAll(',', '.'));
    final w = double.tryParse(weight.text.replaceAll(',', '.'));
    final h = double.tryParse(height.text.replaceAll(',', '.'));
    if (a == null || w == null || h == null || a <= 0 || w <= 0 || h <= 0) return;
    const factors = {'Sedentário': 1.2, 'Levemente ativo': 1.375, 'Moderado': 1.55, 'Muito ativo': 1.725, 'Extremamente ativo': 1.9};
    final bmr = sex == 'Masculino' ? 10 * w + 6.25 * h - 5 * a + 5 : 10 * w + 6.25 * h - 5 * a - 161;
    final kcal = bmr * factors[activity]! + (objective == 'Perder peso' ? -400 : objective == 'Ganhar peso' ? 300 : 0);
    goals = {'calories': kcal, 'protein': w * 2, 'fat': kcal * 0.27 / 9, 'carbs': (kcal - w * 2 * 4 - kcal * 0.27) / 4};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nutrition_goals', '${goals!['calories']}|${goals!['protein']}|${goals!['carbs']}|${goals!['fat']}');
    if (weights.every((e) => e.date != today)) { weights.add(WeightEntry(date: today, weight: w)); await _saveWeights(); }
    if (mounted) setState(() {});
  }

  Future<void> _weight() async {
    final controller = TextEditingController();
    final old = weights.where((e) => e.date == today).toList();
    if (old.isNotEmpty) controller.text = old.first.weight.toString();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Peso de hoje'), content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: 'kg')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar'))]));
    final value = double.tryParse(controller.text.replaceAll(',', '.'));
    if (ok != true || value == null || value <= 0) return;
    weights.removeWhere((e) => e.date == today);
    weights.add(WeightEntry(date: today, weight: value));
    weights.sort((a, b) => a.date.compareTo(b.date));
    await _saveWeights();
    if (mounted) setState(() {});
  }

  Future<void> _manual() async {
    final name = TextEditingController();
    final quantity = TextEditingController();
    final kcal = TextEditingController();
    final protein = TextEditingController();
    final carbs = TextEditingController();
    final fat = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Adicionar alimento'), content: SingleChildScrollView(child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Alimento')), TextField(controller: quantity, decoration: const InputDecoration(labelText: 'Quantidade')), TextField(controller: kcal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Calorias')), TextField(controller: protein, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Proteína (g)')), TextField(controller: carbs, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Carboidratos (g)')), TextField(controller: fat, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Gorduras (g)'))])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Adicionar'))]));
    if (ok != true || name.text.trim().isEmpty) return;
    meals.add(Meal(id: DateTime.now().microsecondsSinceEpoch.toString(), date: today, type: 'Refeição', food: quantity.text.trim().isEmpty ? name.text.trim() : '${name.text.trim()} (${quantity.text.trim()})', calories: double.tryParse(kcal.text.replaceAll(',', '.')) ?? 0, protein: double.tryParse(protein.text.replaceAll(',', '.')) ?? 0, carbs: double.tryParse(carbs.text.replaceAll(',', '.')) ?? 0, fat: double.tryParse(fat.text.replaceAll(',', '.')) ?? 0));
    await _saveMeals();
    if (mounted) setState(() {});
  }

  Future<void> _textAI() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Analisar por texto'), content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Ex.: 150g arroz e 100g frango')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Analisar'))]));
    if (ok != true || controller.text.trim().isEmpty) return;
    try { final result = await ai.estimateText(controller.text); if (mounted) _result(result); } catch (e) { if (mounted) _message(e.toString()); }
  }

  Future<void> _photo() async {
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) return;
    try { final result = await ai.estimateImage(image.path); if (mounted) _result(result); } catch (e) { if (mounted) _message(e.toString()); }
  }

  Future<void> _result(FoodResult result) async {
    final add = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Estimativa nutricional'), content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...result.items.map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item.name), subtitle: Text('${item.grams.toStringAsFixed(0)}g • ${item.calories.toStringAsFixed(0)} kcal • P ${item.protein.toStringAsFixed(1)}g • C ${item.carbs.toStringAsFixed(1)}g • G ${item.fat.toStringAsFixed(1)}g'))), const Divider(), Text('${result.calories.toStringAsFixed(0)} kcal • P ${result.protein.toStringAsFixed(1)}g • C ${result.carbs.toStringAsFixed(1)}g • G ${result.fat.toStringAsFixed(1)}g'), const SizedBox(height: 8), Text(result.note)])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('NÃO CONTAR')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('CONTAR'))]));
    if (add != true) return;
    meals.add(Meal(id: DateTime.now().microsecondsSinceEpoch.toString(), date: today, type: 'Refeição', food: result.items.map((e) => e.name).join(', '), calories: result.calories, protein: result.protein, carbs: result.carbs, fat: result.fat, source: 'ai'));
    await _saveMeals();
    if (mounted) setState(() {});
  }

  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final list = meals.where((e) => e.date == today).toList();
    final kcal = list.fold(0.0, (s, e) => s + e.calories);
    final protein = list.fold(0.0, (s, e) => s + e.protein);
    final carbs = list.fold(0.0, (s, e) => s + e.carbs);
    final fat = list.fold(0.0, (s, e) => s + e.fat);
    final current = weights.isEmpty ? null : weights.last;
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Alimentação', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), Text('${list.length} refeição(ões) hoje')])), IconButton(onPressed: _setup, icon: const Icon(Icons.settings_outlined))]),
      if (goals != null) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Metas diárias', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), _bar('Calorias', kcal, goals!['calories']!, 'kcal'), _bar('Proteína', protein, goals!['protein']!, 'g'), _bar('Carboidratos', carbs, goals!['carbs']!, 'g'), _bar('Gorduras', fat, goals!['fat']!, 'g')])),
      AppCard(child: Row(children: [const Icon(Icons.monitor_weight_outlined, size: 32), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Peso corporal'), Text(current == null ? '—' : '${current.weight.toStringAsFixed(1)} kg', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))])), OutlinedButton(onPressed: _weight, child: const Text('Registrar'))])),
      if (weights.length > 1) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Evolução do peso', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 10), SizedBox(height: 90, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: weights.reversed.take(12).toList().reversed.map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Text(e.weight.toStringAsFixed(1), style: const TextStyle(fontSize: 10)), const SizedBox(height: 4), Container(height: (e.weight / 100 * 70).clamp(8.0, 70.0), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4)))])))).toList()))])),
      Row(children: [Expanded(child: FilledButton.icon(onPressed: _textAI, icon: const Icon(Icons.auto_awesome), label: const Text('Analisar texto'))), const SizedBox(width: 8), IconButton.filled(onPressed: _photo, icon: const Icon(Icons.camera_alt_outlined))]),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(onPressed: _manual, icon: const Icon(Icons.add), label: const Text('Adicionar manualmente')),
      const SizedBox(height: 16),
      Text('Refeições de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      if (list.isEmpty) const AppCard(child: Text('Nenhuma refeição registrada.')),
      ...list.map((meal) => AppCard(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(meal.food), subtitle: Text('${meal.calories.toStringAsFixed(0)} kcal • P ${meal.protein.toStringAsFixed(1)}g • C ${meal.carbs.toStringAsFixed(1)}g • G ${meal.fat.toStringAsFixed(1)}g'), trailing: IconButton(onPressed: () async { meals.remove(meal); await _saveMeals(); if (mounted) setState(() {}); }, icon: const Icon(Icons.delete_outline))))),
    ]));
  }

  Widget _bar(String name, double value, double goal, String unit) { final progress = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0).toDouble(); return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(name)), Text('${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit')]), const SizedBox(height: 4), LinearProgressIndicator(value: progress, minHeight: 7)])); }
}
