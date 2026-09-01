
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime selected = DateTime.now();
  List<AgendaEvent> events = [];

  String get dayKey => DateFormat('yyyy-MM-dd').format(selected);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.read('agenda');
    events = raw.map(AgendaEvent.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _save() => StorageService.write(
        'agenda',
        events.map((event) => event.toJson()).toList(),
      );

  Future<void> _addEvent() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final start = TextEditingController(text: '08:00');
    final end = TextEditingController(text: '09:00');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo compromisso'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: start,
                      decoration: const InputDecoration(labelText: 'Início'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: end,
                      decoration: const InputDecoration(labelText: 'Fim'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    );

    if (result != true || title.text.trim().isEmpty) return;

    setState(() {
      events.add(
        AgendaEvent(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: dayKey,
          title: title.text.trim(),
          description: description.text.trim(),
          start: start.text.trim(),
          end: end.text.trim(),
        ),
      );
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = events.where((event) => event.date == dayKey).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Agenda',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                onPressed: _addEvent,
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
          CalendarDatePicker(
            initialDate: selected,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (date) => setState(() => selected = date),
          ),
          Text(
            DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(selected),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (dayEvents.isEmpty)
            const AppCard(
              child: Text('Nenhum compromisso neste dia.'),
            ),
          ...dayEvents.map(
            (event) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(event.start.split(':').first),
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${event.start} - ${event.end}\n${event.description}',
                ),
                isThreeLine: event.description.isNotEmpty,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    setState(() => events.remove(event));
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
