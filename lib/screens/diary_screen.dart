import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/plan_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<Map<String, dynamic>> notes = [];
  bool loading = true;
  bool premium = false;
  final TextEditingController _content = TextEditingController();
  DateTime selectedDay = DateTime.now();

  String _dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String get _selectedKey => _dayKey(selectedDay);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await StorageService.read('diary_notes');
    final paid = await PlanService().hasPremium;
    notes = loaded;
    premium = paid;
    _syncEditor();
    if (mounted) setState(() => loading = false);
  }

  void _syncEditor() {
    final existing = notes.where((note) => note['date'] == _selectedKey).toList();
    _content.text = existing.isEmpty ? '' : (existing.last['content'] ?? '').toString();
  }

  Future<void> _save() async {
    final text = _content.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algo antes de salvar o diário.')),
      );
      return;
    }
    final sameDay = notes.where((note) => note['date'] == _selectedKey).toList();
    if (!premium && sameDay.isEmpty && !await PlanService().canCreateDiaryNote(_selectedKey)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O plano gratuito permite uma anotação por dia. Conheça o Premium para criar mais.')),
      );
      return;
    }
    if (sameDay.isNotEmpty && !premium) {
      final target = sameDay.last;
      target['content'] = text;
      target['updatedAt'] = DateTime.now().toIso8601String();
    } else {
      notes.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'date': _selectedKey,
        'content': text,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    await StorageService.write('diary_notes', notes);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anotação salva.')),
      );
    }
  }

  Future<void> _selectDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => selectedDay = picked);
    _syncEditor();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final sameDay = notes.where((note) => note['date'] == _selectedKey).toList();
    final dayNotes = [...notes]..sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
    return Scaffold(
      appBar: AppBar(title: const Text('Diário')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seu diário de hoje', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(DateFormat('EEEE, dd/MM/yyyy', 'pt_BR').format(selectedDay)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _selectDay,
                ),
                TextField(
                  controller: _content,
                  minLines: 7,
                  maxLines: 14,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Como foi seu dia? Escreva seus pensamentos, acontecimentos e objetivos...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(sameDay.isEmpty ? 'Salvar diário' : 'Atualizar anotação'),
                  ),
                ),
                if (!premium)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Plano gratuito: uma anotação por dia. Você pode editar a anotação do dia selecionado.'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Anotações anteriores', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (dayNotes.isEmpty)
            const AppCard(child: Text('Suas anotações aparecerão aqui.'))
          else
            ...dayNotes.map((note) => AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(DateFormat('dd/MM/yyyy').format(DateTime.tryParse((note['date'] ?? '').toString()) ?? DateTime.now())),
                subtitle: Text((note['content'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  final date = DateTime.tryParse((note['date'] ?? '').toString());
                  if (date == null) return;
                  setState(() => selectedDay = date);
                  _syncEditor();
                },
              ),
            )),
        ],
      ),
    );
  }
}
