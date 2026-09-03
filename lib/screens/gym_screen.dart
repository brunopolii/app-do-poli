import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const muscleOrder = ['Bíceps','Tríceps','Costas','Peito','Ombros','Quadríceps','Posterior','Glúteos','Panturrilhas','Abdômen'];
const weekdays = ['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'];
const defaultExercises = <List<String>>[
 ['Rosca direta','Bíceps'],['Rosca alternada','Bíceps'],['Rosca Scott','Bíceps'],['Rosca martelo','Bíceps'],
 ['Tríceps corda','Tríceps'],['Tríceps testa','Tríceps'],['Tríceps francês','Tríceps'],['Mergulho','Tríceps'],
 ['Puxada aberta','Costas'],['Puxada fechada','Costas'],['Remada baixa','Costas'],['Remada cavalinho','Costas'],['Remada unilateral','Costas'],['Pullover','Costas'],
 ['Supino reto','Peito'],['Supino inclinado','Peito'],['Crucifixo máquina','Peito'],['Crossover','Peito'],['Flexão','Peito'],
 ['Desenvolvimento','Ombros'],['Elevação lateral','Ombros'],['Elevação frontal','Ombros'],['Crucifixo inverso','Ombros'],
 ['Agachamento','Quadríceps'],['Leg press 45','Quadríceps'],['Cadeira extensora','Quadríceps'],['Afundo','Quadríceps'],
 ['Mesa flexora','Posterior'],['Cadeira flexora','Posterior'],['Stiff','Posterior'],['Terra romeno','Posterior'],
 ['Hip thrust','Glúteos'],['Elevação pélvica','Glúteos'],['Abdução','Glúteos'],['Panturrilha em pé','Panturrilhas'],['Panturrilha sentado','Panturrilhas'],
 ['Abdominal supra','Abdômen'],['Abdominal infra','Abdômen'],['Prancha','Abdômen'],['Elevação de pernas','Abdômen'],
];

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<Workout> workouts = [];
  List<List<String>> custom = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final rawWorkouts = await StorageService.read('workouts');
    final rawCustom = await StorageService.read('exercise_library');
    workouts = rawWorkouts.map(Workout.fromJson).toList();
    custom = rawCustom.map((e) => [(e['name'] ?? '').toString(), (e['muscle'] ?? 'Outros').toString()]).where((e) => e[0].isNotEmpty).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() => StorageService.write('workouts', workouts.map((w) => w.toJson()).toList());

  List<List<String>> get library {
    final result = <List<String>>[...defaultExercises, ...custom];
    final seen = <String>{};
    result.removeWhere((e) => !seen.add('${e[1]}::${e[0].toLowerCase()}'));
    result.sort((a,b) {
      final ai = muscleOrder.indexOf(a[1]);
      final bi = muscleOrder.indexOf(b[1]);
      final ag = ai < 0 ? 999 : ai;
      final bg = bi < 0 ? 999 : bi;
      return ag == bg ? a[0].toLowerCase().compareTo(b[0].toLowerCase()) : ag.compareTo(bg);
    });
    return result;
  }

  Future<void> _createWorkout() async {
    final name = TextEditingController();
    final selected = <int>{DateTime.now().weekday};
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      title: const Text('Novo treino'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome do treino')),
        const SizedBox(height: 16), const Text('Selecione um ou mais dias'), const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: List.generate(7, (i) => FilterChip(label: Text(weekdays[i].substring(0,3)), selected: selected.contains(i+1), onSelected: (v) => ss(() { if (v) selected.add(i+1); else if (selected.length > 1) selected.remove(i+1); }))))
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Criar'))],
    )));
    if (ok != true || name.text.trim().isEmpty) return;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final created = <Workout>[];
    for (final day in selected) {
      final w = Workout(id: '${DateTime.now().microsecondsSinceEpoch}-$day', name: name.text.trim(), date: date, weekday: day, exercises: []);
      workouts.add(w); created.add(w);
    }
    await _save();
    if (mounted) setState(() {});
    if (created.isNotEmpty && mounted) await _editWorkout(created.first);
  }

  Future<void> _addCustomExercise() async {
    final name = TextEditingController();
    String muscle = muscleOrder.first;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      title: const Text('Novo exercício'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome do exercício')),
        DropdownButtonFormField<String>(initialValue: muscle, items: muscleOrder.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) { if (v != null) ss(() => muscle = v); }, decoration: const InputDecoration(labelText: 'Grupo muscular')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar'))],
    )));
    if (ok == true && name.text.trim().isNotEmpty) {
      custom.add([name.text.trim(), muscle]);
      await StorageService.write('exercise_library', custom.map((e) => {'name': e[0], 'muscle': e[1]}).toList());
      if (mounted) setState(() {});
    }
  }

  Future<void> _editWorkout(Workout workout) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => WorkoutEditor(workout: workout, library: library, onChanged: () { setState(() {}); _save(); }, onAddCustom: _addCustomExercise));
    await _save();
  }

  Future<void> _startWorkout(Workout workout) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayer(workout: workout, onSave: _save)));
    if (mounted) setState(() {});
  }

  @override Widget build(BuildContext context) {
    return SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: Text('Academia', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: _createWorkout, icon: const Icon(Icons.add), label: const Text('Novo treino'))]),
      const SizedBox(height: 12),
      if (workouts.isEmpty) const AppCard(child: Text('Crie seu primeiro treino para começar.')),
      ...List.generate(7, (i) {
        final dayWorkouts = workouts.where((w) => w.weekday == i + 1).toList();
        if (dayWorkouts.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 5), child: Text(weekdays[i], style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
          ...dayWorkouts.map((w) => AppCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(child: Icon(Icons.fitness_center)), title: Text(w.name), subtitle: Text('${w.exercises.length} exercícios'), onTap: () => _startWorkout(w), trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'start') await _startWorkout(w); if (v == 'edit') await _editWorkout(w); if (v == 'delete') { setState(() => workouts.remove(w)); await _save(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'start', child: Text('Iniciar treino')), PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))])))),
        ]);
      }),
    ]));
  }
}

class WorkoutEditor extends StatefulWidget {
  final Workout workout; final List<List<String>> library; final VoidCallback onChanged; final Future<void> Function() onAddCustom;
  const WorkoutEditor({super.key, required this.workout, required this.library, required this.onChanged, required this.onAddCustom});
  @override State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  String search = '';

  Future<void> _addExercise() async {
    String? selected; int sets = 3; int reps = 10;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, ss) {
      final query = search.trim().toLowerCase();
      final filtered = widget.library.where((e) => query.isEmpty || e[0].toLowerCase().contains(query) || e[1].toLowerCase().contains(query)).toList();
      return AlertDialog(
        title: const Text('Adicionar exercício'),
        content: SizedBox(width: 520, height: 560, child: Column(children: [
          TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar exercício'), onChanged: (v) => ss(() => search = v)),
          const SizedBox(height: 8),
          Expanded(child: ListView(children: [
            for (final group in muscleOrder) ...[
              Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: Align(alignment: Alignment.centerLeft, child: Text(group, style: const TextStyle(fontWeight: FontWeight.bold)))),
              ...filtered.where((e) => e[1] == group).map((e) => RadioListTile<String>(dense: true, value: e[0], groupValue: selected, title: Text(e[0]), subtitle: Text(e[1]), onChanged: (v) => ss(() => selected = v))),
            ],
            ...filtered.where((e) => !muscleOrder.contains(e[1])).map((e) => RadioListTile<String>(value: e[0], groupValue: selected, title: Text(e[0]), subtitle: Text(e[1]), onChanged: (v) => ss(() => selected = v))),
          ])),
          Row(children: [Expanded(child: DropdownButtonFormField<int>(initialValue: sets, items: [2,3,4,5].map((x) => DropdownMenuItem(value: x, child: Text('$x séries'))).toList(), onChanged: (v) { if (v != null) ss(() => sets = v); }, decoration: const InputDecoration(labelText: 'Séries'))), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<int>(initialValue: reps, items: [5,6,8,10,12,15,20].map((x) => DropdownMenuItem(value: x, child: Text('$x reps'))).toList(), onChanged: (v) { if (v != null) ss(() => reps = v); }, decoration: const InputDecoration(labelText: 'Repetições')))],),
        ])),
        actions: [TextButton(onPressed: widget.onAddCustom, child: const Text('Novo exercício')), TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')), FilledButton(onPressed: selected == null ? null : () => Navigator.pop(c, true), child: const Text('Adicionar'))],
      );
    }));
    if (ok == true && selected != null) {
      final e = widget.library.firstWhere((x) => x[0] == selected);
      setState(() => widget.workout.exercises.add(Exercise(id: DateTime.now().microsecondsSinceEpoch.toString(), name: e[0], muscle: e[1], sets: sets, reps: reps)));
      widget.onChanged();
    }
  }

  @override Widget build(BuildContext context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .9, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    Row(children: [Expanded(child: Text('Editar: ${widget.workout.name}', style: Theme.of(context).textTheme.titleLarge)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
    Expanded(child: ReorderableListView.builder(itemCount: widget.workout.exercises.length, onReorder: (oldIndex, newIndex) { setState(() { if (newIndex > oldIndex) newIndex--; final item = widget.workout.exercises.removeAt(oldIndex); widget.workout.exercises.insert(newIndex, item); }); widget.onChanged(); }, itemBuilder: (c, i) { final e = widget.workout.exercises[i]; return ListTile(key: ValueKey(e.id), leading: const CircleAvatar(child: Icon(Icons.fitness_center)), title: Text(e.name), subtitle: Text('${e.muscle} • ${e.sets} séries × ${e.reps}'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() => widget.workout.exercises.removeAt(i)); widget.onChanged(); })); })),
    FilledButton.icon(onPressed: _addExercise, icon: const Icon(Icons.add), label: const Text('Adicionar exercício')),
  ]))));
}

class WorkoutPlayer extends StatefulWidget {
  final Workout workout; final Future<void> Function() onSave;
  const WorkoutPlayer({super.key, required this.workout, required this.onSave});
  @override State<WorkoutPlayer> createState() => _WorkoutPlayerState();
}
class _WorkoutPlayerState extends State<WorkoutPlayer> {
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.workout.name)), body: ListView(padding: const EdgeInsets.all(16), children: [
    ...widget.workout.exercises.map((e) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(e.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text('${e.muscle} • ${e.sets} séries × ${e.reps} repetições'),
      ...List.generate(e.sets, (i) => Row(children: [Text('Série ${i+1}'), const SizedBox(width: 8), Expanded(child: TextFormField(initialValue: e.weights[i] == 0 ? '' : e.weights[i].toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'kg'), onChanged: (v) => e.weights[i] = double.tryParse(v.replaceAll(',', '.')) ?? 0)), Checkbox(value: e.done[i], onChanged: (v) => setState(() => e.done[i] = v ?? false))])),
    ]))),
    FilledButton(onPressed: () async { await widget.onSave(); if (mounted) Navigator.pop(context); }, child: const Text('Salvar treino')),
  ]));
}
