import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const weekDays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const muscles = ['Peito', 'Costas', 'Ombros', 'Bíceps', 'Tríceps', 'Quadríceps', 'Posterior', 'Glúteos', 'Panturrilhas', 'Abdômen', 'Outros'];
const defaultExercises = <List<String>>[
  ['Supino reto', 'Peito'], ['Supino inclinado', 'Peito'], ['Crucifixo máquina', 'Peito'], ['Crossover', 'Peito'],
  ['Puxada aberta', 'Costas'], ['Remada baixa', 'Costas'], ['Remada unilateral', 'Costas'], ['Pulldown', 'Costas'],
  ['Desenvolvimento', 'Ombros'], ['Elevação lateral', 'Ombros'], ['Elevação frontal', 'Ombros'],
  ['Rosca direta', 'Bíceps'], ['Rosca alternada', 'Bíceps'], ['Rosca martelo', 'Bíceps'],
  ['Tríceps corda', 'Tríceps'], ['Tríceps testa', 'Tríceps'], ['Tríceps francês', 'Tríceps'],
  ['Agachamento', 'Quadríceps'], ['Leg press 45', 'Quadríceps'], ['Cadeira extensora', 'Quadríceps'],
  ['Mesa flexora', 'Posterior'], ['Stiff', 'Posterior'], ['Flexora sentado', 'Posterior'],
  ['Hip thrust', 'Glúteos'], ['Abdução de quadril', 'Glúteos'], ['Panturrilha em pé', 'Panturrilhas'],
  ['Panturrilha sentado', 'Panturrilhas'], ['Abdominal supra', 'Abdômen'], ['Prancha', 'Abdômen'], ['Elevação de pernas', 'Abdômen'],
];

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<WorkoutPlan> plans = [];
  List<List<String>> customExercises = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await StorageService.read('workout_plans');
    final e = await StorageService.read('exercise_library');
    plans = p.map(WorkoutPlan.fromJson).toList();
    customExercises = e.map((x) => [(x['name'] ?? '').toString(), (x['muscle'] ?? 'Outros').toString()]).where((x) => x[0].isNotEmpty).toList();
    if (mounted) setState(() {});
  }

  Future<void> _savePlans() => StorageService.write('workout_plans', plans.map((p) => p.toJson()).toList());

  List<List<String>> get library {
    final all = [...defaultExercises, ...customExercises];
    final seen = <String>{};
    return all.where((e) => seen.add(e[0].trim().toLowerCase())).toList();
  }

  Future<List<String>?> _newExercise() async {
    final name = TextEditingController();
    String muscle = 'Outros';
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
        title: const Text('Novo exercício'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome do exercício')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: muscle, isExpanded: true, items: muscles.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { if (v != null) setDialog(() => muscle = v); }, decoration: const InputDecoration(labelText: 'Grupo muscular')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR')), FilledButton(onPressed: () { final n = name.text.trim(); if (n.isNotEmpty) Navigator.pop(ctx, [n, muscle]); }, child: const Text('SALVAR'))],
      )),
    );
    name.dispose();
    if (result == null) return null;
    final duplicate = customExercises.any((e) => e[0].trim().toLowerCase() == result[0].trim().toLowerCase()) || defaultExercises.any((e) => e[0].trim().toLowerCase() == result[0].trim().toLowerCase());
    if (!duplicate) {
      customExercises.add(result);
      await StorageService.write('exercise_library', customExercises.map((e) => {'name': e[0], 'muscle': e[1]}).toList());
      if (mounted) setState(() {});
    }
    return result;
  }

  Future<void> _createPlan([WorkoutPlan? old]) async {
    final draft = await Navigator.push<WorkoutPlanDraft>(context, MaterialPageRoute(builder: (_) => WorkoutPlanBuilder(initial: old, library: library, onCreateExercise: _newExercise)));
    if (draft == null) return;
    final plan = old ?? WorkoutPlan(id: DateTime.now().microsecondsSinceEpoch.toString(), name: draft.name, weekdays: [], dayExercises: {});
    plan.name = draft.name;
    plan.weekdays = draft.weekdays.toList()..sort();
    plan.dayExercises = draft.dayExercises.map((k, v) => MapEntry(k, v.map((e) => Exercise(id: e.id, name: e.name, muscle: e.muscle, sets: e.sets, reps: e.reps)).toList()));
    if (old == null) plans.add(plan);
    await _savePlans();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino salvo com sucesso.'))); }
  }

  Future<void> _start(WorkoutPlan plan, int day) async {
    final exercises = plan.exercisesFor(day).map((e) => Exercise(id: e.id, name: e.name, muscle: e.muscle, sets: e.sets, reps: e.reps)).toList();
    if (exercises.isEmpty) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayer(name: plan.name, weekday: day, exercises: exercises)));
  }

  Future<void> _delete(WorkoutPlan plan) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Excluir treino?'), content: Text('Excluir "${plan.name}" da configuração? O histórico já realizado será preservado.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('EXCLUIR'))]));
    if (ok != true) return;
    plans.removeWhere((p) => p.id == plan.id);
    await _savePlans();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino excluído.'))); }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final todayPlans = plans.where((p) => p.weekdays.contains(today) && p.exercisesFor(today).isNotEmpty).toList();
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Academia', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), Text('${plans.length} treino(s) configurado(s)')])), FilledButton.icon(onPressed: () => _createPlan(), icon: const Icon(Icons.add), label: const Text('Criar treino'))]),
      const SizedBox(height: 16),
      if (todayPlans.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Treino de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), ...todayPlans.map((p) => ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.fitness_center)), title: Text(p.name), subtitle: Text('${p.exercisesFor(today).length} exercícios • ${weekDays[today - 1]}'), trailing: FilledButton(onPressed: () => _start(p, today), child: const Text('Iniciar')))])),
      _HistorySection(),
      if (plans.isEmpty) const AppCard(child: Column(children: [Icon(Icons.fitness_center_outlined, size: 42), SizedBox(height: 8), Text('Nenhum treino criado', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Crie seu primeiro treino e monte cada dia com exercícios, séries e repetições.', textAlign: TextAlign.center)])),
      ...plans.map((p) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const CircleAvatar(child: Icon(Icons.fitness_center)), const SizedBox(width: 12), Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _createPlan(p); if (v == 'delete') _delete(p); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar treino')), PopupMenuItem(value: 'delete', child: Text('Excluir treino'))])]), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: p.weekdays.map((d) => ActionChip(label: Text(weekDays[d - 1]), onPressed: () => _start(p, d))).toList()), const SizedBox(height: 8), ...p.weekdays.map((d) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${weekDays[d - 1]}: ${p.exercisesFor(d).map((e) => '${e.name} (${e.sets}×${e.reps})').join(', ')}', style: Theme.of(context).textTheme.bodySmall)))]))),
    ]));
  }
}

class WorkoutPlanDraft {
  final String name; final Set<int> weekdays; final Map<String, List<Exercise>> dayExercises;
  WorkoutPlanDraft({required this.name, required this.weekdays, required this.dayExercises});
}

class WorkoutPlanBuilder extends StatefulWidget {
  final WorkoutPlan? initial; final List<List<String>> library; final Future<List<String>?> Function() onCreateExercise;
  const WorkoutPlanBuilder({super.key, this.initial, required this.library, required this.onCreateExercise});
  @override State<WorkoutPlanBuilder> createState() => _WorkoutPlanBuilderState();
}

class _WorkoutPlanBuilderState extends State<WorkoutPlanBuilder> {
  late TextEditingController name; final selectedDays = <int>{}; final dayExercises = <String, List<Exercise>>{};
  @override void initState() { super.initState(); name = TextEditingController(text: widget.initial?.name ?? ''); if (widget.initial != null) { selectedDays.addAll(widget.initial!.weekdays); widget.initial!.dayExercises.forEach((k, v) => dayExercises[k] = v.map((e) => Exercise(id: e.id, name: e.name, muscle: e.muscle, sets: e.sets, reps: e.reps)).toList()); } }
  @override void dispose() { name.dispose(); super.dispose(); }
  Future<void> _openDay(int day) async { final result = await Navigator.push<List<Exercise>>(context, MaterialPageRoute(builder: (_) => DayExerciseEditor(day: day, initial: (dayExercises['$day'] ?? []).map((e) => e.copy()).toList(), library: widget.library, onCreateExercise: widget.onCreateExercise))); if (result != null && mounted) setState(() { selectedDays.add(day); dayExercises['$day'] = result; }); }
  void _save() { final valid = selectedDays.where((d) => (dayExercises['$d'] ?? []).isNotEmpty).toSet(); if (name.text.trim().isEmpty || valid.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(name.text.trim().isEmpty ? 'Dê um nome ao treino.' : 'Adicione exercícios a pelo menos um dia.'))); return; } Navigator.pop(context, WorkoutPlanDraft(name: name.text.trim(), weekdays: valid, dayExercises: dayExercises)); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.initial == null ? 'Criar treino' : 'Editar treino')), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do treino')), const SizedBox(height: 20), Text('Dias da semana', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), ...List.generate(7, (i) { final d = i + 1; final count = dayExercises['$d']?.length ?? 0; return Card(child: ListTile(leading: CircleAvatar(child: Text('$d')), title: Text(weekDays[i]), subtitle: Text(count == 0 ? 'Adicionar exercícios' : '$count exercício(s) configurado(s)'), trailing: const Icon(Icons.chevron_right), onTap: () => _openDay(d))); }), const SizedBox(height: 12), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('SALVAR TREINO'))]));
}

class DayExerciseEditor extends StatefulWidget {
  final int day; final List<Exercise> initial; final List<List<String>> library; final Future<List<String>?> Function() onCreateExercise;
  const DayExerciseEditor({super.key, required this.day, required this.initial, required this.library, required this.onCreateExercise});
  @override State<DayExerciseEditor> createState() => _DayExerciseEditorState();
}
class _DayExerciseEditorState extends State<DayExerciseEditor> {
  late List<Exercise> exercises;
  @override void initState() { super.initState(); exercises = widget.initial; }
  Future<void> _add() async { final result = await showDialog<Exercise>(context: context, builder: (_) => ExercisePicker(library: widget.library, onCreateExercise: widget.onCreateExercise)); if (result != null && mounted) setState(() => exercises.add(result)); }
  Future<void> _edit(Exercise e) async { final result = await showDialog<Exercise>(context: context, builder: (_) => ExerciseSettings(initial: e)); if (result != null && mounted) { final i = exercises.indexOf(e); if (i >= 0) setState(() => exercises[i] = result); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(weekDays[widget.day - 1]), actions: [TextButton(onPressed: () => Navigator.pop(context, exercises), child: const Text('SALVAR'))]), body: ListView(padding: const EdgeInsets.all(16), children: [Text('Exercícios', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), ...List.generate(exercises.length, (i) => Card(child: ListTile(leading: CircleAvatar(child: Text('${i + 1}')), title: Text(exercises[i].name), subtitle: Text('${exercises[i].muscle} • ${exercises[i].sets} séries × ${exercises[i].reps} reps'), trailing: Wrap(children: [IconButton(onPressed: () => _edit(exercises[i]), icon: const Icon(Icons.tune)), IconButton(onPressed: () => setState(() => exercises.removeAt(i)), icon: const Icon(Icons.delete_outline))]))), const SizedBox(height: 8), OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('ADICIONAR EXERCÍCIO'))]));
}

class ExercisePicker extends StatefulWidget {
  final List<List<String>> library; final Future<List<String>?> Function() onCreateExercise;
  const ExercisePicker({super.key, required this.library, required this.onCreateExercise});
  @override State<ExercisePicker> createState() => _ExercisePickerState();
}
class _ExercisePickerState extends State<ExercisePicker> {
  String query = ''; String muscle = 'Todos'; String? selected;
  @override Widget build(BuildContext context) { final items = widget.library.where((e) => (muscle == 'Todos' || e[1] == muscle) && (e[0].toLowerCase().contains(query.toLowerCase()) || e[1].toLowerCase().contains(query.toLowerCase()))).toList(); return AlertDialog(title: const Text('Escolher exercício'), content: SizedBox(width: 520, height: 520, child: Column(children: [TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar')), const SizedBox(height: 8), DropdownButtonFormField<String>(value: muscle, isExpanded: true, items: ['Todos', ...muscles].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { if (v != null) setState(() => muscle = v); }, decoration: const InputDecoration(labelText: 'Grupo muscular')), const SizedBox(height: 8), Expanded(child: ListView(children: items.map((e) => ListTile(selected: selected == e[0], leading: CircleAvatar(child: Text(e[0][0].toUpperCase())), title: Text(e[0]), subtitle: Text(e[1]), onTap: () => setState(() => selected = e[0]))).toList()))]), actions: [TextButton(onPressed: () async { final e = await widget.onCreateExercise(); if (e != null && mounted) setState(() { selected = e[0]; }); }, child: const Text('NOVO EXERCÍCIO')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')), FilledButton(onPressed: () { if (selected == null) return; final e = widget.library.firstWhere((x) => x[0] == selected); Navigator.pop(context, Exercise(id: DateTime.now().microsecondsSinceEpoch.toString(), name: e[0], muscle: e[1], sets: 3, reps: 10)); }, child: const Text('ADICIONAR'))])); }
}

class ExerciseSettings extends StatefulWidget { final Exercise initial; const ExerciseSettings({super.key, required this.initial}); @override State<ExerciseSettings> createState() => _ExerciseSettingsState(); }
class _ExerciseSettingsState extends State<ExerciseSettings> {
  late int sets; late int reps;
  @override void initState() { super.initState(); sets = widget.initial.sets; reps = widget.initial.reps; }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.initial.name), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Séries: $sets'), Slider(value: sets.toDouble(), min: 1, max: 12, divisions: 11, onChanged: (v) => setState(() => sets = v.round())), Text('Repetições: $reps'), Slider(value: reps.toDouble(), min: 1, max: 30, divisions: 29, onChanged: (v) => setState(() => reps = v.round())), const Text('A carga (kg) é informada somente durante a execução.', textAlign: TextAlign.center)]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')), FilledButton(onPressed: () => Navigator.pop(context, Exercise(id: widget.initial.id, name: widget.initial.name, muscle: widget.initial.muscle, sets: sets, reps: reps)), child: const Text('SALVAR'))]);
}

class WorkoutPlayer extends StatefulWidget {
  final String name; final int weekday; final List<Exercise> exercises;
  const WorkoutPlayer({super.key, required this.name, required this.weekday, required this.exercises});
  @override State<WorkoutPlayer> createState() => _WorkoutPlayerState();
}
class _WorkoutPlayerState extends State<WorkoutPlayer> {
  late List<List<TextEditingController>> controllers;
  late List<List<bool>> done;
  @override void initState() { super.initState(); controllers = widget.exercises.map((e) => List.generate(e.sets, (_) => TextEditingController())).toList(); done = widget.exercises.map((e) => List<bool>.filled(e.sets, false)).toList(); }
  @override void dispose() { for (final row in controllers) { for (final c in row) c.dispose(); } super.dispose(); }
  double? _weight(int i, int s) => double.tryParse(controllers[i][s].text.trim().replaceAll(',', '.'));
  Future<void> _finish() async {
    for (var i = 0; i < widget.exercises.length; i++) { for (var s = 0; s < widget.exercises[i].sets; s++) { final w = _weight(i, s); if (!done[i][s] || w == null || w < 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conclua todas as séries e informe uma carga válida em cada série.'))); return; } } }
    final completed = <Exercise>[];
    for (var i = 0; i < widget.exercises.length; i++) { final e = widget.exercises[i].copy(); e.weights = List.generate(e.sets, (s) => _weight(i, s)!); e.done = [...done[i]]; completed.add(e); }
    final history = await StorageService.read('workout_history');
    history.add(Workout(id: DateTime.now().microsecondsSinceEpoch.toString(), name: widget.name, date: DateTime.now().toIso8601String(), weekday: widget.weekday, exercises: completed).toJson());
    await StorageService.write('workout_history', history);
    if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino concluído e salvo no histórico.'))); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.name)), body: ListView(padding: const EdgeInsets.all(16), children: [Text('Treino em execução', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Informe a carga usada em cada série e marque-a como concluída.'), const SizedBox(height: 12), ...List.generate(widget.exercises.length, (i) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.exercises[i].name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text(widget.exercises[i].muscle), const SizedBox(height: 10), ...List.generate(widget.exercises[i].sets, (s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [SizedBox(width: 62, child: Text('Série ${s + 1}')), SizedBox(width: 88, child: TextField(controller: controllers[i][s], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'kg'))), const SizedBox(width: 8), Expanded(child: Text('${widget.exercises[i].reps} reps')), Checkbox(value: done[i][s], onChanged: (v) => setState(() => done[i][s] = v == true))]))]))), const SizedBox(height: 8), FilledButton.icon(onPressed: _finish, icon: const Icon(Icons.check), label: const Text('FINALIZAR TREINO'))]));
}

class _HistorySection extends StatefulWidget { @override State<_HistorySection> createState() => _HistorySectionState(); }
class _HistorySectionState extends State<_HistorySection> {
  List<Workout> history = []; String? exercise;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { history = (await StorageService.read('workout_history')).map(Workout.fromJson).toList()..sort((a,b) => a.date.compareTo(b.date)); if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) { if (history.isEmpty) return const SizedBox.shrink(); final names = history.expand((w) => w.exercises.map((e) => e.name)).toSet().toList()..sort(); exercise ??= names.isNotEmpty ? names.first : null; if (exercise != null && !names.contains(exercise)) exercise = names.first; final points = <Workout>[]; for (final w in history) { if (w.exercises.any((e) => e.name == exercise && e.weights.any((x) => x > 0))) points.add(w); }
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.show_chart), const SizedBox(width: 8), Expanded(child: Text('Histórico e evolução', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)))]), const SizedBox(height: 8), DropdownButtonFormField<String>(value: exercise, isExpanded: true, items: names.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => exercise = v), decoration: const InputDecoration(labelText: 'Exercício')), const SizedBox(height: 10), if (points.isEmpty) const Text('Ainda não há cargas registradas.') else ...points.reversed.take(8).map((w) { final ex = w.exercises.firstWhere((e) => e.name == exercise); final max = ex.weights.fold<double>(0, (a,b) => b > a ? b : a); return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.fitness_center), title: Text('${max.toStringAsFixed(1)} kg'), subtitle: Text(w.date.substring(0, 10)); }), const SizedBox(height: 8), Text('A evolução usa a maior carga de cada exercício registrada em cada treino.', style: Theme.of(context).textTheme.bodySmall)])); }
}
