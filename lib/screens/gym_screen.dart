import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const List<String> weekDays = <String>['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const List<String> muscles = <String>['Peito', 'Costas', 'Ombros', 'Bíceps', 'Tríceps', 'Quadríceps', 'Posterior', 'Glúteos', 'Panturrilhas', 'Abdômen', 'Outros'];
const List<List<String>> defaultExercises = <List<String>>[
  ['Supino reto', 'Peito'], ['Supino inclinado', 'Peito'], ['Crucifixo máquina', 'Peito'], ['Crossover', 'Peito'],
  ['Puxada aberta', 'Costas'], ['Remada baixa', 'Costas'], ['Remada unilateral', 'Costas'], ['Pulldown', 'Costas'],
  ['Desenvolvimento', 'Ombros'], ['Elevação lateral', 'Ombros'], ['Elevação frontal', 'Ombros'],
  ['Rosca direta', 'Bíceps'], ['Rosca alternada', 'Bíceps'], ['Rosca martelo', 'Bíceps'],
  ['Tríceps corda', 'Tríceps'], ['Tríceps testa', 'Tríceps'], ['Tríceps francês', 'Tríceps'],
  ['Agachamento', 'Quadríceps'], ['Leg press 45', 'Quadríceps'], ['Cadeira extensora', 'Quadríceps'],
  ['Mesa flexora', 'Posterior'], ['Stiff', 'Posterior'], ['Flexora sentado', 'Posterior'],
  ['Hip thrust', 'Glúteos'], ['Abdução de quadril', 'Glúteos'],
  ['Panturrilha em pé', 'Panturrilhas'], ['Panturrilha sentado', 'Panturrilhas'],
  ['Abdominal supra', 'Abdômen'], ['Prancha', 'Abdômen'], ['Elevação de pernas', 'Abdômen'],
];

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<WorkoutPlan> plans = <WorkoutPlan>[];
  List<List<String>> customExercises = <List<String>>[];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final planData = await StorageService.read('workout_plans');
    final exerciseData = await StorageService.read('exercise_library');
    plans = planData.map(WorkoutPlan.fromJson).toList();
    customExercises = exerciseData.map((e) => <String>[(e['name'] ?? '').toString(), (e['muscle'] ?? 'Outros').toString()]).where((e) => e[0].isNotEmpty).toList();
    if (mounted) setState(() {});
  }

  Future<void> _savePlans() => StorageService.write('workout_plans', plans.map((e) => e.toJson()).toList());

  List<List<String>> get library {
    final all = <List<String>>[...defaultExercises, ...customExercises];
    final seen = <String>{};
    return all.where((e) => seen.add(e[0].toLowerCase())).toList();
  }

  Future<void> _createPlan([WorkoutPlan? old]) async {
    final result = await Navigator.push<WorkoutPlanDraft>(context, MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => WorkoutPlanBuilder(initial: old, library: library, onCreateExercise: _newExercise),
    ));
    if (result == null || result.name.trim().isEmpty || result.weekdays.isEmpty) return;
    final plan = old ?? WorkoutPlan(id: DateTime.now().microsecondsSinceEpoch.toString(), name: result.name.trim(), weekdays: <int>[], dayExercises: <String, List<Exercise>>{});
    plan.name = result.name.trim();
    plan.weekdays = result.weekdays.toList()..sort();
    plan.dayExercises = result.dayExercises;
    plans.removeWhere((p) => p.id == plan.id);
    plans.add(plan);
    await _savePlans();
    if (mounted) setState(() {});
  }

  Future<List<String>?> _newExercise() async {
    final name = TextEditingController();
    String muscle = 'Outros';
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setD) => AlertDialog(
      title: const Text('Novo exercício'),
      content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome do exercício')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: muscle, items: muscles.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) setD(() => muscle = v); }, decoration: const InputDecoration(labelText: 'Grupo muscular')),
      ]),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar')),
      ],
    )));
    if (ok != true || name.text.trim().isEmpty) return null;
    final item = <String>[name.text.trim(), muscle];
    customExercises.add(item);
    await StorageService.write('exercise_library', customExercises.map((e) => <String, dynamic>{'name': e[0], 'muscle': e[1]}).toList());
    if (mounted) setState(() {});
    return item;
  }

  Future<void> _start(WorkoutPlan plan, int day) async {
    final list = plan.exercisesFor(day).map((e) => e.copy()).toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este dia ainda não tem exercícios.')));
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayer(name: plan.name, exercises: list)));
  }

  @override Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final todayPlans = plans.where((p) => p.weekdays.contains(today)).toList();
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: <Widget>[
      Row(children: <Widget>[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text('Academia', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('${plans.length} treino(s) configurado(s)'),
        ])),
        FilledButton.icon(onPressed: () => _createPlan(), icon: const Icon(Icons.add), label: const Text('Criar treino')),
      ]),
      const SizedBox(height: 16),
      if (todayPlans.isNotEmpty) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text('Treino de hoje', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        for (final p in todayPlans) ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.fitness_center)), title: Text(p.name), subtitle: Text('${p.exercisesFor(today).length} exercícios • ${weekDays[today - 1]}'), trailing: FilledButton(onPressed: () => _start(p, today), child: const Text('Iniciar'))),
      ])),
      if (plans.isEmpty) const AppCard(child: Column(children: <Widget>[
        Icon(Icons.fitness_center_outlined, size: 42), SizedBox(height: 8),
        Text('Nenhum treino criado', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 4),
        Text('Crie seu primeiro treino e monte cada dia com os exercícios, séries e repetições que quiser.', textAlign: TextAlign.center),
      ])),
      for (final p in plans) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          const CircleAvatar(child: Icon(Icons.fitness_center)), const SizedBox(width: 12),
          Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
          PopupMenuButton<String>(onSelected: (v) async {
            if (v == 'edit') await _createPlan(p);
            if (v == 'delete') { plans.removeWhere((x) => x.id == p.id); await _savePlans(); if (mounted) setState(() {}); }
          }, itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'edit', child: Text('Editar treino')),
            PopupMenuItem<String>(value: 'delete', child: Text('Excluir treino')),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: p.weekdays.map((day) => ActionChip(avatar: const Icon(Icons.calendar_today, size: 16), label: Text(weekDays[day - 1]), onPressed: () => _start(p, day))).toList()),
        const SizedBox(height: 10),
        Text('${p.weekdays.fold<int>(0, (sum, day) => sum + p.exercisesFor(day).length)} exercícios distribuídos nos dias', style: Theme.of(context).textTheme.bodySmall),
      ])),
    ]));
  }
}

class WorkoutPlanDraft {
  final String name;
  final Set<int> weekdays;
  final Map<String, List<Exercise>> dayExercises;
  WorkoutPlanDraft({required this.name, required this.weekdays, required this.dayExercises});
}

class WorkoutPlanBuilder extends StatefulWidget {
  final WorkoutPlan? initial;
  final List<List<String>> library;
  final Future<List<String>?> Function() onCreateExercise;
  const WorkoutPlanBuilder({super.key, this.initial, required this.library, required this.onCreateExercise});
  @override State<WorkoutPlanBuilder> createState() => _WorkoutPlanBuilderState();
}

class _WorkoutPlanBuilderState extends State<WorkoutPlanBuilder> {
  late final TextEditingController name;
  final Set<int> selectedDays = <int>{};
  final Map<String, List<Exercise>> dayExercises = <String, List<Exercise>>{};

  @override void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial?.name ?? '');
    if (widget.initial != null) {
      selectedDays.addAll(widget.initial!.weekdays);
      for (final e in widget.initial!.dayExercises.entries) dayExercises[e.key] = e.value.map((x) => x.copy()).toList();
    }
  }

  @override void dispose() { name.dispose(); super.dispose(); }

  Future<void> _openDay(int day) async {
    setState(() => selectedDays.add(day));
    final result = await Navigator.push<List<Exercise>>(context, MaterialPageRoute(builder: (_) => DayExerciseEditor(
      day: day,
      initial: (dayExercises['$day'] ?? <Exercise>[]).map((e) => e.copy()).toList(),
      library: widget.library,
      onCreateExercise: widget.onCreateExercise,
    )));
    if (result != null) setState(() => dayExercises['$day'] = result);
  }

  void _saveWorkout() {
    if (name.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dê um nome ao treino.'))); return; }
    if (selectedDays.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha pelo menos um dia.'))); return; }
    final validDays = selectedDays.where((d) => (dayExercises['$d'] ?? <Exercise>[]).isNotEmpty).toSet();
    if (validDays.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione exercícios a pelo menos um dia.'))); return; }
    Navigator.pop(context, WorkoutPlanDraft(name: name.text.trim(), weekdays: validDays, dayExercises: dayExercises));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Criar treino' : 'Editar treino')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: <Widget>[
        Text('Nome do treino', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Ex.: Treino A • Hipertrofia', prefixIcon: Icon(Icons.edit_outlined))),
        const SizedBox(height: 24),
        Text('Escolha os dias', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Toque em um dia para abrir a aba de exercícios desse dia.'),
        const SizedBox(height: 12),
        for (int index = 0; index < 7; index++) _dayCard(index + 1),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _saveWorkout, icon: const Icon(Icons.save_outlined), label: const Text('SALVAR TREINO'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      ]),
    );
  }

  Widget _dayCard(int day) {
    final exercises = dayExercises['$day'] ?? <Exercise>[];
    final selected = selectedDays.contains(day);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
      leading: CircleAvatar(child: Text(day.toString())),
      title: Text(weekDays[day - 1], style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(selected ? '${exercises.length} exercício(s) • toque para editar' : 'Toque para montar este dia'),
      trailing: Icon(selected ? Icons.chevron_right : Icons.add_circle_outline),
      onTap: () => _openDay(day),
    )));
  }
}

class DayExerciseEditor extends StatefulWidget {
  final int day;
  final List<Exercise> initial;
  final List<List<String>> library;
  final Future<List<String>?> Function() onCreateExercise;
  const DayExerciseEditor({super.key, required this.day, required this.initial, required this.library, required this.onCreateExercise});
  @override State<DayExerciseEditor> createState() => _DayExerciseEditorState();
}

class _DayExerciseEditorState extends State<DayExerciseEditor> {
  late List<Exercise> exercises;
  @override void initState() { super.initState(); exercises = widget.initial; }

  Future<void> _addExercise() async {
    final exercise = await showDialog<Exercise>(context: context, builder: (_) => ExercisePicker(library: widget.library, onCreateExercise: widget.onCreateExercise));
    if (exercise != null) setState(() => exercises.add(exercise));
  }

  Future<void> _editExercise(Exercise exercise) async {
    final result = await showDialog<Exercise>(context: context, builder: (_) => ExerciseSettings(initial: exercise));
    if (result == null) return;
    final index = exercises.indexWhere((e) => e.id == exercise.id);
    if (index >= 0) setState(() => exercises[index] = result);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(weekDays[widget.day - 1]), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context, exercises), child: const Text('SALVAR'))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: <Widget>[
        Text('Exercícios', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const Text('Adicione quantos exercícios quiser e defina séries e repetições de cada um.'),
        const SizedBox(height: 16),
        if (exercises.isEmpty) AppCard(child: Column(children: <Widget>[
          const Icon(Icons.playlist_add, size: 42), const SizedBox(height: 8),
          const Text('Nenhum exercício neste dia', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4),
          const Text('Toque em Adicionar exercício para começar.'),
        ])),
        for (int i = 0; i < exercises.length; i++) _exerciseCard(exercises[i], i),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _addExercise, icon: const Icon(Icons.add), label: const Text('ADICIONAR EXERCÍCIO'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
      ]),
    );
  }

  Widget _exerciseCard(Exercise e, int index) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        CircleAvatar(child: Text('${index + 1}')), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(e.muscle),
        ])),
        IconButton(onPressed: () => _editExercise(e), icon: const Icon(Icons.tune), tooltip: 'Séries e repetições'),
        IconButton(onPressed: () => setState(() => exercises.remove(e)), icon: const Icon(Icons.delete_outline), tooltip: 'Remover'),
      ]),
      const SizedBox(height: 8),
      Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.surfaceContainerHighest), child: Text('${e.sets} séries × ${e.reps} repetições', style: const TextStyle(fontWeight: FontWeight.w600))),
    ])));
  }
}

class ExercisePicker extends StatefulWidget {
  final List<List<String>> library;
  final Future<List<String>?> Function() onCreateExercise;
  const ExercisePicker({super.key, required this.library, required this.onCreateExercise});
  @override State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  String query = '';
  String? selectedName;
  @override Widget build(BuildContext context) {
    final items = widget.library.where((e) => e[0].toLowerCase().contains(query.toLowerCase()) || e[1].toLowerCase().contains(query.toLowerCase())).toList();
    final grouped = <String, List<List<String>>>{};
    for (final e in items) grouped.putIfAbsent(e[1], () => <List<String>>[]).add(e);
    return AlertDialog(
      title: const Text('Escolher exercício'),
      content: SizedBox(width: 520, height: 540, child: Column(children: <Widget>[
        TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar exercício ou músculo')),
        const SizedBox(height: 8),
        Expanded(child: ListView(children: grouped.entries.expand((entry) => <Widget>[
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))),
          ...entry.value.map((e) => ListTile(dense: true, selected: selectedName == e[0], leading: CircleAvatar(radius: 18, child: Text(e[0].substring(0, 1).toUpperCase())), title: Text(e[0]), onTap: () => setState(() => selectedName = e[0]))),
        ]).toList())),
      ])),
      actions: <Widget>[
        TextButton(onPressed: () async { final created = await widget.onCreateExercise(); if (created != null && mounted) setState(() {}); }, child: const Text('NOVO EXERCÍCIO')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        FilledButton(onPressed: selectedName == null ? null : () async {
          final data = widget.library.firstWhere((e) => e[0] == selectedName);
          final settings = await showDialog<Exercise>(context: context, builder: (_) => ExerciseSettings(initial: Exercise(id: DateTime.now().microsecondsSinceEpoch.toString(), name: data[0], muscle: data[1], sets: 3, reps: 10)));
          if (settings != null && mounted) Navigator.pop(context, settings);
        }, child: const Text('ADICIONAR')),
      ],
    );
  }
}

class ExerciseSettings extends StatefulWidget {
  final Exercise initial;
  const ExerciseSettings({super.key, required this.initial});
  @override State<ExerciseSettings> createState() => _ExerciseSettingsState();
}

class _ExerciseSettingsState extends State<ExerciseSettings> {
  late int sets;
  late int reps;
  @override void initState() { super.initState(); sets = widget.initial.sets; reps = widget.initial.reps; }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.name),
      content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(widget.initial.muscle), const SizedBox(height: 12),
        DropdownButtonFormField<int>(initialValue: sets, items: List<int>.generate(10, (i) => i + 1).map((e) => DropdownMenuItem<int>(value: e, child: Text('$e séries'))).toList(), onChanged: (v) { if (v != null) setState(() => sets = v); }, decoration: const InputDecoration(labelText: 'Séries')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(initialValue: reps, items: <int>[1, 2, 3, 5, 6, 8, 10, 12, 15, 20, 25, 30].map((e) => DropdownMenuItem<int>(value: e, child: Text('$e repetições'))).toList(), onChanged: (v) { if (v != null) setState(() => reps = v); }, decoration: const InputDecoration(labelText: 'Repetições')),
      ]),
      actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')), FilledButton(onPressed: () => Navigator.pop(context, Exercise(id: widget.initial.id, name: widget.initial.name, muscle: widget.initial.muscle, sets: sets, reps: reps, weights: widget.initial.weights, done: widget.initial.done)), child: const Text('SALVAR'))],
    );
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
    final data = <String, dynamic>{'date': DateFormat('yyyy-MM-dd').format(DateTime.now()), 'name': widget.name, 'exercises': widget.exercises.map((e) => e.toJson()).toList()};
    await StorageService.write('last_workout_session', <Map<String, dynamic>>[data]);
    if (mounted) Navigator.pop(context);
  }
  @override Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final exercise in widget.exercises) {
      final exerciseChildren = <Widget>[Text(exercise.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text('${exercise.muscle} • ${exercise.sets} séries × ${exercise.reps} reps'), const SizedBox(height: 8)];
      for (int index = 0; index < exercise.sets; index++) {
        exerciseChildren.add(Row(children: <Widget>[
          SizedBox(width: 60, child: Text('Série ${index + 1}')),
          Expanded(child: TextFormField(initialValue: exercise.weights[index] == 0 ? '' : exercise.weights[index].toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Carga kg'), onChanged: (v) => exercise.weights[index] = double.tryParse(v.replaceAll(',', '.')) ?? 0)),
          Checkbox(value: exercise.done[index], onChanged: (v) => setState(() => exercise.done[index] = v ?? false)),
        ]));
      }
      children.add(AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: exerciseChildren)));
    }
    children.add(const SizedBox(height: 12));
    children.add(FilledButton.icon(onPressed: _finish, icon: const Icon(Icons.check), label: const Text('FINALIZAR TREINO')));
    return Scaffold(appBar: AppBar(title: Text(widget.name)), body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: children)));
  }
}
