import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const weekdays = <String>['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const muscles = <String>['Peito', 'Costas', 'Ombros', 'Bíceps', 'Tríceps', 'Quadríceps', 'Posterior', 'Glúteos', 'Panturrilhas', 'Abdômen', 'Outros'];
const exercises = <List<String>>[
  ['Supino reto', 'Peito'], ['Supino inclinado', 'Peito'], ['Crucifixo máquina', 'Peito'], ['Crossover', 'Peito'],
  ['Puxada aberta', 'Costas'], ['Remada baixa', 'Costas'], ['Remada unilateral', 'Costas'], ['Desenvolvimento', 'Ombros'],
  ['Elevação lateral', 'Ombros'], ['Rosca direta', 'Bíceps'], ['Rosca alternada', 'Bíceps'], ['Rosca martelo', 'Bíceps'],
  ['Tríceps corda', 'Tríceps'], ['Tríceps testa', 'Tríceps'], ['Agachamento', 'Quadríceps'], ['Leg press 45', 'Quadríceps'],
  ['Cadeira extensora', 'Quadríceps'], ['Mesa flexora', 'Posterior'], ['Stiff', 'Posterior'], ['Hip thrust', 'Glúteos'],
  ['Panturrilha em pé', 'Panturrilhas'], ['Panturrilha sentado', 'Panturrilhas'], ['Abdominal supra', 'Abdômen'], ['Prancha', 'Abdômen'],
];

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<WorkoutPlan> plans = [];
  List<List<String>> custom = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    plans = (await StorageService.read('workout_plans')).map(WorkoutPlan.fromJson).toList();
    custom = (await StorageService.read('exercise_library')).map((e) => [(e['name'] ?? '').toString(), (e['muscle'] ?? 'Outros').toString()]).where((e) => e[0].isNotEmpty).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() => StorageService.write('workout_plans', plans.map((e) => e.toJson()).toList());

  List<List<String>> get library {
    final result = <List<String>>[...exercises, ...custom];
    final seen = <String>{};
    return result.where((e) => seen.add(e[0].toLowerCase())).toList();
  }

  Future<void> _create([WorkoutPlan? old]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final selectedDays = <int>{...(old?.weekdays ?? <int>[])};
    if (selectedDays.isEmpty) selectedDays.add(DateTime.now().weekday);
    final dayExercises = <String, List<Exercise>>{};
    if (old != null) for (final entry in old.dayExercises.entries) dayExercises[entry.key] = entry.value.map((e) => e.copy()).toList();
    int selectedDay = selectedDays.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(old == null ? 'Criar treino' : 'Editar treino'),
          content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do treino', prefixIcon: Icon(Icons.edit_outlined))),
            const SizedBox(height: 18),
            const Text('Dias da semana', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 6, children: List.generate(7, (index) {
              final day = index + 1;
              return FilterChip(label: Text(weekdays[index].substring(0, 3)), selected: selectedDays.contains(day), onSelected: (value) { setDialogState(() { if (value) { selectedDays.add(day); selectedDay = day; } else if (selectedDays.length > 1) { selectedDays.remove(day); if (selectedDay == day) selectedDay = selectedDays.first; } }); });
            })),
            const SizedBox(height: 18),
            Text('Exercícios de ${weekdays[selectedDay - 1]}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ...(dayExercises['$selectedDay'] ?? <Exercise>[]).map((exercise) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.fitness_center), title: Text(exercise.name), subtitle: Text('${exercise.sets} séries × ${exercise.reps} reps'), trailing: IconButton(onPressed: () => setDialogState(() => dayExercises['$selectedDay']!.remove(exercise)), icon: const Icon(Icons.delete_outline)))),
            OutlinedButton.icon(onPressed: () async { final changed = await _pickExercise(context, dayExercises, selectedDay); if (changed) setDialogState(() {}); }, icon: const Icon(Icons.add), label: const Text('Adicionar exercício')),
          ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar'))],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    final plan = old ?? WorkoutPlan(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.text.trim(), weekdays: [], dayExercises: {});
    plan.name = name.text.trim();
    plan.weekdays = selectedDays.toList()..sort();
    plan.dayExercises = dayExercises;
    plans.removeWhere((p) => p.id == plan.id);
    plans.add(plan);
    await _save();
    if (mounted) setState(() {});
  }

  Future<bool> _pickExercise(BuildContext parent, Map<String, List<Exercise>> target, int day) async {
    String query = '';
    String? selected;
    int sets = 3;
    int reps = 10;
    final added = await showDialog<bool>(
      context: parent,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
        final items = library.where((e) => e[0].toLowerCase().contains(query.toLowerCase()) || e[1].toLowerCase().contains(query.toLowerCase())).toList();
        return AlertDialog(
          title: const Text('Escolher exercício'),
          content: SizedBox(width: 520, height: 500, child: Column(children: [
            TextField(onChanged: (value) => setDialogState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar exercício')),
            const SizedBox(height: 8),
            Expanded(child: ListView(children: items.map((e) => RadioListTile<String>(value: e[0], groupValue: selected, onChanged: (v) => setDialogState(() => selected = v), title: Text(e[0]), subtitle: Text(e[1]))).toList())),
            Row(children: [Expanded(child: DropdownButtonFormField<int>(value: sets, items: [2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e séries'))).toList(), onChanged: (v) { if (v != null) setDialogState(() => sets = v); }, decoration: const InputDecoration(labelText: 'Séries'))), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<int>(value: reps, items: [5, 6, 8, 10, 12, 15, 20].map((e) => DropdownMenuItem(value: e, child: Text('$e reps'))).toList(), onChanged: (v) { if (v != null) setDialogState(() => reps = v); }, decoration: const InputDecoration(labelText: 'Reps')))]),
          ])),
          actions: [TextButton(onPressed: () => _newExercise(), child: const Text('Novo exercício')), TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: selected == null ? null : () => Navigator.pop(dialogContext, true), child: const Text('Adicionar'))],
        );
      }),
    );
    if (added != true || selected == null) return false;
    final data = library.firstWhere((e) => e[0] == selected);
    target.putIfAbsent('$day', () => []).add(Exercise(id: DateTime.now().microsecondsSinceEpoch.toString(), name: data[0], muscle: data[1], sets: sets, reps: reps));
    return true;
  }

  Future<void> _newExercise() async {
    final name = TextEditingController();
    String muscle = 'Outros';
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: const Text('Novo exercício'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')), DropdownButtonFormField<String>(value: muscle, items: muscles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setDialogState(() => muscle = v); }, decoration: const InputDecoration(labelText: 'Grupo muscular'))]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar'))])));
    if (ok != true || name.text.trim().isEmpty) return;
    custom.add([name.text.trim(), muscle]);
    await StorageService.write('exercise_library', custom.map((e) => {'name': e[0], 'muscle': e[1]}).toList());
    if (mounted) setState(() {});
  }

  Future<void> _start(WorkoutPlan plan, int day) async {
    final list = plan.exercisesFor(day).map((e) => e.copy()).toList();
    if (list.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione exercícios para este dia primeiro.'))); return; }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayer(name: plan.name, exercises: list)));
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final todayPlans = plans.where((p) => p.weekdays.contains(today)).toList();
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Academia', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), Text('${plans.length} treino(s) configurado(s)')])), FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Criar treino'))]),
      const SizedBox(height: 16),
      if (todayPlans.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Treino de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), ...todayPlans.map((p) => ListTile(contentPadding: EdgeInsets.zero, title: Text(p.name), subtitle: Text('${p.exercisesFor(today).length} exercícios'), trailing: FilledButton(onPressed: () => _start(p, today), child: const Text('Iniciar'))))])),
      if (plans.isEmpty) const AppCard(child: Text('Crie seu primeiro treino escolhendo dias, exercícios, séries e repetições.')),
      ...plans.map((p) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.fitness_center), const SizedBox(width: 8), Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), PopupMenuButton<String>(onSelected: (value) async { if (value == 'edit') await _create(p); if (value == 'delete') { plans.removeWhere((e) => e.id == p.id); await _save(); if (mounted) setState(() {}); } }, itemBuilder: (context) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))])]), Wrap(spacing: 6, children: p.weekdays.map((day) => ActionChip(label: Text(weekdays[day - 1]), onPressed: () => _start(p, day))).toList())]))),
    ]));
  }
}

class WorkoutPlayer extends StatefulWidget {
  final String name;
  final List<Exercise> exercises;
  const WorkoutPlayer({super.key, required this.name, required this.exercises});
  @override State<WorkoutPlayer> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends State<WorkoutPlayer> {
  Future<void> _finish() async {
    await StorageService.write('last_workout_session', [{'date': DateFormat('yyyy-MM-dd').format(DateTime.now()), 'name': widget.name, 'exercises': widget.exercises.map((e) => e.toJson()).toList()}]);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(widget.name)), body: ListView(padding: const EdgeInsets.all(16), children: [...widget.exercises.map((exercise) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(exercise.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text('${exercise.muscle} • ${exercise.sets} séries × ${exercise.reps} reps'), ...List.generate(exercise.sets, (index) => Row(children: [SizedBox(width: 60, child: Text('Série ${index + 1}')), Expanded(child: TextFormField(initialValue: exercise.weights[index] == 0 ? '' : exercise.weights[index].toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Carga kg'), onChanged: (value) => exercise.weights[index] = double.tryParse(value.replaceAll(',', '.')) ?? 0)), Checkbox(value: exercise.done[index], onChanged: (value) => setState(() => exercise.done[index] = value ?? false))]))])), const SizedBox(height: 12), FilledButton.icon(onPressed: _finish, icon: const Icon(Icons.check), label: const Text('Finalizar treino'))]));
  }
}
