
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const exerciseLibrary = <List<String>>[
  ['Supino reto', 'Peito'],
  ['Supino inclinado', 'Peito'],
  ['Crucifixo máquina', 'Peito'],
  ['Crossover', 'Peito'],
  ['Flexão', 'Peito'],
  ['Puxada aberta', 'Costas'],
  ['Puxada fechada', 'Costas'],
  ['Remada baixa', 'Costas'],
  ['Remada cavalinho', 'Costas'],
  ['Remada unilateral', 'Costas'],
  ['Pullover', 'Costas'],
  ['Desenvolvimento', 'Ombros'],
  ['Elevação lateral', 'Ombros'],
  ['Elevação frontal', 'Ombros'],
  ['Crucifixo inverso', 'Ombros'],
  ['Rosca direta', 'Bíceps'],
  ['Rosca alternada', 'Bíceps'],
  ['Rosca Scott', 'Bíceps'],
  ['Rosca martelo', 'Bíceps'],
  ['Tríceps corda', 'Tríceps'],
  ['Tríceps testa', 'Tríceps'],
  ['Tríceps francês', 'Tríceps'],
  ['Mergulho', 'Tríceps'],
  ['Agachamento', 'Quadríceps'],
  ['Leg press 45', 'Quadríceps'],
  ['Cadeira extensora', 'Quadríceps'],
  ['Afundo', 'Quadríceps'],
  ['Mesa flexora', 'Posterior'],
  ['Cadeira flexora', 'Posterior'],
  ['Stiff', 'Posterior'],
  ['Terra romeno', 'Posterior'],
  ['Hip thrust', 'Glúteos'],
  ['Elevação pélvica', 'Glúteos'],
  ['Abdução', 'Glúteos'],
  ['Panturrilha em pé', 'Panturrilhas'],
  ['Panturrilha sentado', 'Panturrilhas'],
  ['Abdominal supra', 'Abdômen'],
  ['Abdominal infra', 'Abdômen'],
  ['Prancha', 'Abdômen'],
  ['Elevação de pernas', 'Abdômen'],
];

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});

  @override
  State<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends State<GymScreen> {
  List<Workout> workouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.read('workouts');
    workouts = raw.map(Workout.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() => StorageService.write(
        'workouts',
        workouts.map((workout) => workout.toJson()).toList(),
      );

  Future<void> _createWorkout() async {
    final name = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo treino'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do treino'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );

    if (result != true || name.text.trim().isEmpty) return;

    final workout = Workout(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      exercises: [],
    );

    setState(() => workouts.add(workout));
    await _save();
    if (mounted) _editWorkout(workout);
  }

  Future<void> _editWorkout(Workout workout) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WorkoutEditor(
        workout: workout,
        onChanged: () {
          setState(() {});
          _save();
        },
      ),
    );
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _startWorkout(Workout workout) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlayer(
          workout: workout,
          onSave: _save,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Academia',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: _createWorkout,
                icon: const Icon(Icons.add),
                label: const Text('Novo treino'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (workouts.isEmpty)
            const AppCard(
              child: Text('Crie seu primeiro treino para começar.'),
            ),
          ...workouts.map(
            (workout) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.fitness_center),
                ),
                title: Text(workout.name),
                subtitle: Text('${workout.exercises.length} exercícios'),
                onTap: () => _startWorkout(workout),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'start') {
                      await _startWorkout(workout);
                    } else if (value == 'edit') {
                      await _editWorkout(workout);
                    } else if (value == 'delete') {
                      setState(() => workouts.remove(workout));
                      await _save();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'start',
                      child: Text('Iniciar treino'),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutEditor extends StatefulWidget {
  final Workout workout;
  final VoidCallback onChanged;

  const WorkoutEditor({
    super.key,
    required this.workout,
    required this.onChanged,
  });

  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> {
  String group = 'Todos';

  Future<void> _addExercise() async {
    final filtered = exerciseLibrary
        .where((item) => group == 'Todos' || item[1] == group)
        .toList();

    if (filtered.isEmpty) return;

    String selected = filtered.first[0];
    int sets = 3;
    int reps = 10;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar exercício'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                items: filtered
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item[0],
                        child: Text(item[0]),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selected = value);
                  }
                },
                decoration: const InputDecoration(labelText: 'Exercício'),
              ),
              DropdownButtonFormField<int>(
                value: sets,
                items: [2, 3, 4, 5]
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value séries'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => sets = value);
                  }
                },
                decoration: const InputDecoration(labelText: 'Séries'),
              ),
              DropdownButtonFormField<int>(
                value: reps,
                items: [5, 6, 8, 10, 12, 15, 20]
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value repetições'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => reps = value);
                  }
                },
                decoration: const InputDecoration(labelText: 'Repetições'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final muscle = filtered.firstWhere((item) => item[0] == selected)[1];
    setState(() {
      widget.workout.exercises.add(
        Exercise(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: selected,
          muscle: muscle,
          sets: sets,
          reps: reps,
        ),
      );
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String>[
      'Todos',
      'Peito',
      'Costas',
      'Ombros',
      'Bíceps',
      'Tríceps',
      'Quadríceps',
      'Posterior',
      'Glúteos',
      'Panturrilhas',
      'Abdômen',
    ];

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar: ${widget.workout.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: group,
                items: groups
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => group = value);
                },
                decoration:
                    const InputDecoration(labelText: 'Grupo muscular'),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.workout.exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = widget.workout.exercises[index];
                    return ListTile(
                      title: Text(exercise.name),
                      subtitle:
                          Text('${exercise.sets} séries × ${exercise.reps}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(
                            () => widget.workout.exercises.removeAt(index),
                          );
                          widget.onChanged();
                        },
                      ),
                    );
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar exercício'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutPlayer extends StatefulWidget {
  final Workout workout;
  final Future<void> Function() onSave;

  const WorkoutPlayer({
    super.key,
    required this.workout,
    required this.onSave,
  });

  @override
  State<WorkoutPlayer> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends State<WorkoutPlayer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.workout.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Treino do dia',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Registre a carga de cada série e marque quando concluir.',
          ),
          const SizedBox(height: 12),
          if (widget.workout.exercises.isEmpty)
            const AppCard(
              child: Text('Este treino ainda não possui exercícios.'),
            ),
          ...widget.workout.exercises.map(
            (exercise) => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${exercise.sets} séries × ${exercise.reps} repetições • ${exercise.muscle}',
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    exercise.sets,
                    (index) => Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: Text('Série ${index + 1}'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: exercise.weights[index] == 0
                                ? ''
                                : exercise.weights[index].toString(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'kg',
                              suffixText: 'kg',
                            ),
                            onChanged: (value) {
                              exercise.weights[index] =
                                  double.tryParse(value.replaceAll(',', '.')) ??
                                      0;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Checkbox(
                          value: exercise.done[index],
                          onChanged: (value) {
                            setState(
                              () => exercise.done[index] = value ?? false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () async {
              await widget.onSave();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('Finalizar treino'),
          ),
        ],
      ),
    );
  }
}
