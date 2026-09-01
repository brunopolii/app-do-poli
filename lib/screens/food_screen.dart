
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
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
  final AiFoodService ai = AiFoodService();
  final ImagePicker picker = ImagePicker();
  List<Meal> meals = [];

  String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.read('meals');
    meals = raw.map(Meal.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() => StorageService.write(
        'meals',
        meals.map((meal) => meal.toJson()).toList(),
      );

  Future<void> _analyzeText() async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('IA por texto'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText:
                'Ex.: 200g arroz, 150g frango e 100g feijão',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Analisar'),
          ),
        ],
      ),
    );

    if (result != true || controller.text.trim().isEmpty) return;

    try {
      final food = await ai.estimateText(controller.text);
      if (mounted) await _showResult(food);
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  Future<void> _analyzeCamera() async {
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (photo == null) return;

    try {
      final food = await ai.estimateImage(photo.path);
      if (mounted) await _showResult(food);
    } catch (error) {
      if (mounted) _showError(error.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showResult(FoodResult result) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estimativa nutricional'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...result.items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.grams.toStringAsFixed(0)}g • '
                    '${item.calories.toStringAsFixed(0)} kcal\n'
                    'P ${item.protein.toStringAsFixed(1)}g • '
                    'C ${item.carbs.toStringAsFixed(1)}g • '
                    'G ${item.fat.toStringAsFixed(1)}g',
                  ),
                ),
              ),
              const Divider(),
              Text(
                'Total: ${result.calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'P ${result.protein.toStringAsFixed(1)}g • '
                'C ${result.carbs.toStringAsFixed(1)}g • '
                'G ${result.fat.toStringAsFixed(1)}g',
              ),
              const SizedBox(height: 8),
              Text(
                result.note,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (add != true) return;

    setState(() {
      meals.add(
        Meal(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: today,
          type: 'Refeição',
          food: result.items.map((item) => item.name).join(', '),
          calories: result.calories,
          protein: result.protein,
          carbs: result.carbs,
          fat: result.fat,
          source: 'ai',
        ),
      );
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final todayMeals = meals.where((meal) => meal.date == today).toList();
    final calories =
        todayMeals.fold<double>(0, (sum, meal) => sum + meal.calories);
    final protein =
        todayMeals.fold<double>(0, (sum, meal) => sum + meal.protein);
    final carbs =
        todayMeals.fold<double>(0, (sum, meal) => sum + meal.carbs);
    final fat = todayMeals.fold<double>(0, (sum, meal) => sum + meal.fat);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alimentação',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'text') _analyzeText();
                  if (value == 'camera') _analyzeCamera();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'text',
                    child: Text('🤖 Analisar por texto'),
                  ),
                  PopupMenuItem(
                    value: 'camera',
                    child: Text('📷 Analisar com câmera'),
                  ),
                ],
              ),
            ],
          ),
          AppCard(
            child: Column(
              children: [
                Text(
                  '${calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Proteína ${protein.toStringAsFixed(1)}g • '
                  'Carbo ${carbs.toStringAsFixed(1)}g • '
                  'Gordura ${fat.toStringAsFixed(1)}g',
                ),
              ],
            ),
          ),
          if (todayMeals.isEmpty)
            const AppCard(
              child: Text(
                'Nenhuma refeição registrada hoje. Use o menu acima para analisar uma refeição.',
              ),
            ),
          ...todayMeals.map(
            (meal) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(meal.food),
                subtitle: Text(
                  '${meal.calories.toStringAsFixed(0)} kcal • '
                  'P ${meal.protein.toStringAsFixed(1)}g • '
                  'C ${meal.carbs.toStringAsFixed(1)}g • '
                  'G ${meal.fat.toStringAsFixed(1)}g',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    setState(() => meals.remove(meal));
                    await _save();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
