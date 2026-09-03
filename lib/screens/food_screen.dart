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
  final ai = AiFoodService();
  final picker = ImagePicker();
  List<Meal> meals = [];
  Map<String, double>? goals;
  bool loading = true;
  String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final rawMeals = await StorageService.read('meals');
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('nutrition_goals');
    meals = rawMeals.map(Meal.fromJson).toList();
    if (encoded != null) {
      final parts = encoded.split('|');
      if (parts.length == 4) goals = {'calories': double.tryParse(parts[0]) ?? 0, 'protein': double.tryParse(parts[1]) ?? 0, 'carbs': double.tryParse(parts[2]) ?? 0, 'fat': double.tryParse(parts[3]) ?? 0};
    }
    if (mounted) setState(() => loading = false);
    if (goals == null && mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  Future<void> _setup() async {
    final age = TextEditingController(); final weight = TextEditingController(); final height = TextEditingController();
    String sex = 'Masculino'; String activity = 'Moderado'; String objective = 'Manter peso';
    final ok = await showDialog<bool>(context: context, barrierDismissible: false, builder: (c) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      title: const Text('Configure sua alimentação'),
      content: SingleChildScrollView(child: Column(children: [
        const Text('Vamos estimar suas metas diárias de calorias e macronutrientes.'),
        TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Idade')),
        TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso (kg)')),
        TextField(controller: height, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Altura (cm)')),
        DropdownButtonFormField<String>(initialValue: sex, items: const [DropdownMenuItem(value: 'Masculino', child: Text('Masculino')), DropdownMenuItem(value: 'Feminino', child: Text('Feminino'))], onChanged: (v) { if (v != null) ss(() => sex = v); }, decoration: const InputDecoration(labelText: 'Sexo')),
        DropdownButtonFormField<String>(initialValue: activity, items: const [DropdownMenuItem(value: 'Sedentário', child: Text('Sedentário')), DropdownMenuItem(value: 'Levemente ativo', child: Text('Levemente ativo')), DropdownMenuItem(value: 'Moderado', child: Text('Moderado')), DropdownMenuItem(value: 'Muito ativo', child: Text('Muito ativo')), DropdownMenuItem(value: 'Extremamente ativo', child: Text('Extremamente ativo'))], onChanged: (v) { if (v != null) ss(() => activity = v); }, decoration: const InputDecoration(labelText: 'Nível de atividade')),
        DropdownButtonFormField<String>(initialValue: objective, items: const [DropdownMenuItem(value: 'Perder peso', child: Text('Perder peso')), DropdownMenuItem(value: 'Manter peso', child: Text('Manter peso')), DropdownMenuItem(value: 'Ganhar peso', child: Text('Ganhar peso'))], onChanged: (v) { if (v != null) ss(() => objective = v); }, decoration: const InputDecoration(labelText: 'Objetivo')),
        const SizedBox(height: 12), const Text('São estimativas e não substituem orientação de nutricionista ou médico.', style: TextStyle(fontSize: 12)),
      ])),
      actions: [FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Calcular metas'))],
    )));
    if (ok != true) return;
    final a = double.tryParse(age.text.replaceAll(',', '.')); final w = double.tryParse(weight.text.replaceAll(',', '.')); final h = double.tryParse(height.text.replaceAll(',', '.'));
    if (a == null || w == null || h == null || a <= 0 || w <= 0 || h <= 0) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha todos os dados corretamente.'))); return; }
    const factors = {'Sedentário': 1.2, 'Levemente ativo': 1.375, 'Moderado': 1.55, 'Muito ativo': 1.725, 'Extremamente ativo': 1.9};
    final bmr = sex == 'Masculino' ? 10 * w + 6.25 * h - 5 * a + 5 : 10 * w + 6.25 * h - 5 * a - 161;
    final kcal = bmr * factors[activity]! + (objective == 'Perder peso' ? -400 : objective == 'Ganhar peso' ? 300 : 0);
    final protein = w * 2; final fat = kcal * .27 / 9; final carbs = (kcal - protein * 4 - fat * 9) / 4;
    goals = {'calories': kcal, 'protein': protein, 'carbs': carbs, 'fat': fat};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nutrition_goals', '${kcal}|${protein}|${carbs}|${fat}');
    if (mounted) setState(() {});
  }

  Future<void> _saveMeals() => StorageService.write('meals', meals.map((m) => m.toJson()).toList());

  Future<void> _manual() async {
    final n = TextEditingController(); final q = TextEditingController(); final k = TextEditingController(); final p = TextEditingController(); final c = TextEditingController(); final f = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (x) => AlertDialog(title: const Text('Adicionar refeição'), content: SingleChildScrollView(child: Column(children: [
      TextField(controller: n, decoration: const InputDecoration(labelText: 'Alimento / refeição')),
      TextField(controller: q, decoration: const InputDecoration(labelText: 'Quantidade (opcional)')),
      TextField(controller: k, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Calorias (kcal)')),
      TextField(controller: p, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Proteína (g)')),
      TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Carboidratos (g)')),
      TextField(controller: f, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Gorduras (g)')),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(x), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('Adicionar'))]));
    if (ok == true && n.text.trim().isNotEmpty) {
      meals.add(Meal(id: DateTime.now().microsecondsSinceEpoch.toString(), date: today, type: 'Refeição', food: q.text.trim().isEmpty ? n.text.trim() : '${n.text.trim()} (${q.text.trim()})', calories: double.tryParse(k.text.replaceAll(',', '.')) ?? 0, protein: double.tryParse(p.text.replaceAll(',', '.')) ?? 0, carbs: double.tryParse(c.text.replaceAll(',', '.')) ?? 0, fat: double.tryParse(f.text.replaceAll(',', '.')) ?? 0));
      await _saveMeals(); if (mounted) setState(() {});
    }
  }

  Future<void> _aiText() async {
    final t = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Analisar por IA'), content: TextField(controller: t, maxLines: 4, decoration: const InputDecoration(hintText: 'Ex.: 200g arroz, 150g frango e feijão')), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Analisar'))]));
    if (ok != true || t.text.trim().isEmpty) return;
    try { final result = await ai.estimateText(t.text); if (mounted) _showResult(result); } catch (e) { if (mounted) _error(e.toString()); }
  }

  Future<void> _camera() async {
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 80); if (photo == null) return;
    try { final result = await ai.estimateImage(photo.path); if (mounted) _showResult(result); } catch (e) { if (mounted) _error(e.toString()); }
  }

  void _error(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _showResult(FoodResult result) async {
    final add = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Estimativa nutricional'), content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...result.items.map((i) => ListTile(contentPadding: EdgeInsets.zero, title: Text(i.name), subtitle: Text('${i.grams.toStringAsFixed(0)}g • ${i.calories.toStringAsFixed(0)} kcal • P ${i.protein.toStringAsFixed(1)}g • C ${i.carbs.toStringAsFixed(1)}g • G ${i.fat.toStringAsFixed(1)}g'))),
      const Divider(), Text('${result.calories.toStringAsFixed(0)} kcal • P ${result.protein.toStringAsFixed(1)}g • C ${result.carbs.toStringAsFixed(1)}g • G ${result.fat.toStringAsFixed(1)}g'), const SizedBox(height: 8), Text(result.note, style: Theme.of(c).textTheme.bodySmall),
    ])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('NÃO CONTAR')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('CONTAR'))]));
    if (add == true) { meals.add(Meal(id: DateTime.now().microsecondsSinceEpoch.toString(), date: today, type: 'Refeição', food: result.items.map((i) => i.name).join(', '), calories: result.calories, protein: result.protein, carbs: result.carbs, fat: result.fat, source: 'ai')); await _saveMeals(); if (mounted) setState(() {}); }
  }

  @override Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final todayMeals = meals.where((m) => m.date == today).toList();
    final kcal = todayMeals.fold<double>(0, (sum, m) => sum + m.calories); final protein = todayMeals.fold<double>(0, (sum, m) => sum + m.protein); final carbs = todayMeals.fold<double>(0, (sum, m) => sum + m.carbs); final fat = todayMeals.fold<double>(0, (sum, m) => sum + m.fat);
    return SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text('Alimentação', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))), PopupMenuButton<String>(onSelected: (v) { if (v == 'text') _aiText(); if (v == 'camera') _camera(); if (v == 'goals') _setup(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'text', child: Text('🤖 Analisar por texto')), PopupMenuItem(value: 'camera', child: Text('📷 Analisar com câmera')), PopupMenuItem(value: 'goals', child: Text('⚙️ Recalcular metas'))])]),
      if (goals != null) AppCard(child: Column(children: [_bar('Calorias', kcal, goals!['calories']!, 'kcal'), _bar('Proteína', protein, goals!['protein']!, 'g'), _bar('Carboidratos', carbs, goals!['carbs']!, 'g'), _bar('Gorduras', fat, goals!['fat']!, 'g')])),
      const SizedBox(height: 8), const Text('As metas são estimativas e não substituem orientação profissional.'), const SizedBox(height: 8),
      FilledButton.icon(onPressed: _manual, icon: const Icon(Icons.add), label: const Text('Adicionar refeição manualmente')),
      ...todayMeals.map((m) => AppCard(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(m.food), subtitle: Text('${m.calories.toStringAsFixed(0)} kcal • P ${m.protein.toStringAsFixed(1)}g • C ${m.carbs.toStringAsFixed(1)}g • G ${m.fat.toStringAsFixed(1)}g'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { meals.remove(m); await _saveMeals(); if (mounted) setState(() {}); })))),
    ]));
  }

  Widget _bar(String name, double value, double goal, String unit) {
    final pct = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0).toDouble();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(name)), Text('${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit')]), const SizedBox(height: 4), LinearProgressIndicator(value: pct)]));
  }
}
