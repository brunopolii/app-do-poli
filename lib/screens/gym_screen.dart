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

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await StorageService.read('workout_plans');
    final e = await StorageService.read('exercise_library');
    plans = p.map(WorkoutPlan.fromJson).toList();
    customExercises = e.map((x) => <String>[(x['name'] ?? '').toString(), (x['muscle'] ?? 'Outros').toString()]).where((x) => x[0].isNotEmpty).toList();
    if (mounted) setState(() {});
  }

  Future<void> _savePlans() => StorageService.write('workout_plans', plans.map((p) => p.toJson()).toList());

  List<List<String>> get library {
    final all = <List<String>>[...defaultExercises, ...customExercises];
    final seen = <String>{};
    return all.where((e) => seen.add(e[0].trim().toLowerCase())).toList();
  }

  Future<List<String>?> _newExercise() async {
    final name = TextEditingController();
    String muscle = muscles.last;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo exercício'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome do exercício')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: muscle,
              items: muscles.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) { if (v != null) setDialogState(() => muscle = v); },
              decoration: const InputDecoration(labelText: 'Grupo muscular'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
            FilledButton(onPressed: () { final n = name.text.trim(); if (n.isNotEmpty) Navigator.pop(dialogContext, [n, muscle]); }, child: const Text('SALVAR')),
          ],
        ),
      ),
    );
    name.dispose();
    if (result == null) return null;
    if (!customExercises.any((e) => e[0].toLowerCase() == result[0].toLowerCase())) {
      customExercises.add(result);
      await StorageService.write('exercise_library', customExercises.map((e) => {'name': e[0], 'muscle': e[1]}).toList());
    }
    if (mounted) setState(() {});
    return result;
  }

  Future<void> _createPlan([WorkoutPlan? old]) async {
    final draft = await Navigator.push<WorkoutPlanDraft>(context, MaterialPageRoute(builder: (_) => WorkoutPlanBuilder(initial: old, library: library, onCreateExercise: _newExercise)));
    if (draft == null) return;
    final plan = old ?? WorkoutPlan(id: DateTime.now().microsecondsSinceEpoch.toString(), name: draft.name, weekdays: [], dayExercises: {});
    plan.name = draft.name;
    plan.weekdays = draft.weekdays.toList()..sort();
    plan.dayExercises = draft.dayExercises;
    plans.removeWhere((p) => p.id == plan.id);
    plans.add(plan);
    await _savePlans();
    if (mounted) setState(() {});
  }

  Future<void> _start(WorkoutPlan plan, int day) async {
    final exercises = plan.exercisesFor(day).map((e) => e.copy()).toList();
    if (exercises.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este dia ainda não tem exercícios.'))); return; }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayer(name: plan.name, exercises: exercises)));
  }

  @override Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final todayPlans = plans.where((p) => p.weekdays.contains(today)).toList();
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Academia', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), Text('${plans.length} treino(s) configurado(s)')])),
        FilledButton.icon(onPressed: () => _createPlan(), icon: const Icon(Icons.add), label: const Text('Criar treino')),
      ]),
      const SizedBox(height: 16),
      if (todayPlans.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Treino de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        for (final p in todayPlans) ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.fitness_center)), title: Text(p.name), subtitle: Text('${p.exercisesFor(today).length} exercícios • ${weekDays[today - 1]}'), trailing: FilledButton(onPressed: () => _start(p, today), child: const Text('Iniciar'))),
      ])),
      if (plans.isEmpty) const AppCard(child: Column(children: [Icon(Icons.fitness_center_outlined, size: 42), SizedBox(height: 8), Text('Nenhum treino criado', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Crie seu primeiro treino e monte cada dia com os exercícios, séries e repetições que quiser.', textAlign: TextAlign.center)])),
      for (final p in plans) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const CircleAvatar(child: Icon(Icons.fitness_center)), const SizedBox(width: 12), Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await _createPlan(p); if (v == 'delete') { plans.removeWhere((x) => x.id == p.id); await _savePlans(); if (mounted) setState(() {}); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar treino')), PopupMenuItem(value: 'delete', child: Text('Excluir treino'))])]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: p.weekdays.map((d) => ActionChip(label: Text(weekDays[d - 1]), onPressed: () => _start(p, d))).toList()),
        const SizedBox(height: 10),
        Text('${p.weekdays.fold<int>(0, (sum, d) => sum + p.exercisesFor(d).length)} exercícios distribuídos nos dias', style: Theme.of(context).textTheme.bodySmall),
      ])),
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
  late TextEditingController name;
  final selectedDays = <int>{};
  final dayExercises = <String, List<Exercise>>{};
  @override void initState() { super.initState(); name = TextEditingController(text: widget.initial?.name ?? ''); if (widget.initial != null) { selectedDays.addAll(widget.initial!.weekdays); widget.initial!.dayExercises.forEach((k, v) { dayExercises[k] = v.map((e) => e.copy()).toList(); }); } }
  @override void dispose() { name.dispose(); super.dispose(); }

  Future<void> _openDay(int day) async {
    final result = await Navigator.push<List<Exercise>>(context, MaterialPageRoute(builder: (_) => DayExerciseEditor(day: day, initial: (dayExercises['$day'] ?? []).map((e) => e.copy()).toList(), library: widget.library, onCreateExercise: widget.onCreateExercise)));
    if (result != null && mounted) setState(() { selectedDays.add(day); dayExercises['$day'] = result; });
  }

  void _save() {
    final valid = selectedDays.where((d) => (dayExercises['$d'] ?? []).isNotEmpty).toSet();
    if (name.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao treino.'))); return; }
    if (valid.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione exercícios a pelo menos um dia.'))); return; }
    Navigator.pop(context, WorkoutPlanDraft(name: name.text.trim(), weekdays: valid, dayExercises: dayExercises));
  }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.initial == null ? 'Criar treino' : 'Editar treino')), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
    TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do treino', prefixIcon: Icon(Icons.edit_outlined))),
    const SizedBox(height: 24), Text('Escolha os dias', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 4), const Text('Toque em um dia para abrir imediatamente a tela de exercícios.'), const SizedBox(height: 12),
    for (int d = 1; d <= 7; d++) Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(leading: CircleAvatar(child: Text('$d')), title: Text(weekDays[d - 1], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text((dayExercises['$d'] ?? []).isEmpty ? 'Toque para montar este dia' : '${dayExercises['$d']!.length} exercício(s) • toque para editar'), trailing: const Icon(Icons.chevron_right), onTap: () => _openDay(d)))),
    const SizedBox(height: 12), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('SALVAR TREINO'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
  ]));
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
  Future<void> _edit(Exercise exercise) async { final result = await showDialog<Exercise>(context: context, builder: (_) => ExerciseSettings(initial: exercise)); if (result != null && mounted) { final index = exercises.indexOf(exercise); if (index >= 0) setState(() => exercises[index] = result); } }

  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(weekDays[widget.day - 1]), actions: [TextButton(onPressed: () => Navigator.pop(context, exercises), child: const Text('SALVAR'))]), body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
    Text('Exercícios', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const Text('Adicione exercícios e defina séries e repetições de cada um.'), const SizedBox(height: 16),
    if (exercises.isEmpty) const AppCard(child: Column(children: [Icon(Icons.playlist_add, size: 42), SizedBox(height: 8), Text('Nenhum exercício neste dia', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Use o botão abaixo para adicionar.') ])),
    for (int i = 0; i < exercises.length; i++) Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [CircleAvatar(child: Text('${i + 1}')), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(exercises[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), Text(exercises[i].muscle), const SizedBox(height: 4), Text('${exercises[i].sets} séries × ${exercises[i].reps} repetições') ])), IconButton(onPressed: () => _edit(exercises[i]), icon: const Icon(Icons.tune)), IconButton(onPressed: () => setState(() => exercises.removeAt(i)), icon: const Icon(Icons.delete_outline)) ]))),
    const SizedBox(height: 8), OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('ADICIONAR EXERCÍCIO'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
  ]));
}

class ExercisePicker extends StatefulWidget {
  final List<List<String>> library; final Future<List<String>?> Function() onCreateExercise;
  const ExercisePicker({super.key, required this.library, required this.onCreateExercise});
  @override State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  late List<List<String>> items; String query = ''; String? selected;
  @override void initState() { super.initState(); items = widget.library.map((e) => [e[0], e[1]]).toList(); }
  Future<void> _new() async { final result = await widget.onCreateExercise(); if (result != null && mounted) setState(() { items.removeWhere((e) => e[0].toLowerCase() == result[0].toLowerCase()); items.add(result); selected = result[0]; }); }
  Future<void> _add() async { if (selected == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um exercício.'))); return; } final data = items.firstWhere((e) => e[0] == selected); final result = await showDialog<Exercise>(context: context, builder: (_) => ExerciseSettings(initial: Exercise(id: DateTime.now().microsecondsSinceEpoch.toString(), name: data[0], muscle: data[1], sets: 3, reps: 10))); if (result != null && mounted) Navigator.pop(context, result); }

  @override Widget build(BuildContext context) { final filtered = items.where((e) => e[0].toLowerCase().contains(query.toLowerCase()) || e[1].toLowerCase().contains(query.toLowerCase())).toList(); return AlertDialog(title: const Text('Escolher exercício'), content: SizedBox(width: 520, height: 500, child: Column(children: [TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar exercício ou músculo')), const SizedBox(height: 8), Expanded(child: ListView(children: filtered.map((e) => ListTile(selected: selected == e[0], leading: CircleAvatar(child: Text(e[0].substring(0, 1).toUpperCase())), title: Text(e[0]), subtitle: Text(e[1]), onTap: () => setState(() => selected = e[0]))).toList()))])), actions: [TextButton(onPressed: _new, child: const Text('NOVO EXERCÍCIO')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')), FilledButton(onPressed: _add, child: const Text('ADICIONAR'))]); }
}

class ExerciseSettings extends StatefulWidget {
  final Exercise initial;
  const ExerciseSettings({super.key, required this.initial});
  @override State<ExerciseSettings> createState() => _ExerciseSettingsState();
}

class _ExerciseSettingsState extends State<ExerciseSettings> {
  late int sets; late int reps;
  @override void initState() { super.initState(); sets = widget.initial.sets; reps = widget.initial.reps; }
  void _save() { Navigator.pop(context, Exercise(id: widget.initial.id, name: widget.initial.name, muscle: widget.initial.muscle, sets: sets, reps: reps, weights: widget.initial.weights, done: widget.initial.done)); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.initial.name), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Séries: $sets'), Slider(value: sets.toDouble(), min: 1, max: 8, divisions: 7, label: '$sets', onChanged: (v) => setState(() => sets = v.round())), Text('Repetições: $reps'), Slider(value: reps.toDouble(), min: 1, max: 30, divisions: 29, label: '$reps', onChanged: (v) => setState(() => reps = v.round()))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')), FilledButton(onPressed: _save, child: const Text('SALVAR'))]);
}

class WorkoutPlayer extends StatefulWidget {
  final String name; final List<Exercise> exercises;
  const WorkoutPlayer({super.key, required this.name, required this.exercises});
  @override State<WorkoutPlayer> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends State<WorkoutPlayer> {
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.name)), body: ListView(padding: const EdgeInsets.all(16), children: [
    Text('Treino em execução', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 12),
    for (int i = 0; i < widget.exercises.length; i++) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.exercises[i].name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), Text(widget.exercises[i].muscle), const SizedBox(height: 8), for (int s = 0; s < widget.exercises[i].sets; s++) Row(children: [Text('Série ${s + 1}'), const Spacer(), SizedBox(width: 90, child: TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'kg'))), const SizedBox(width: 8), SizedBox(width: 90, child: Text('${widget.exercises[i].reps} reps'))]) ])),
    const SizedBox(height: 8), FilledButton(onPressed: () => Navigator.pop(context), child: const Text('FINALIZAR TREINO')),
  ]));
}
