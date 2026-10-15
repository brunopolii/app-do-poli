import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';

class PremiumDiaryScreen extends StatefulWidget {
  const PremiumDiaryScreen({super.key});

  @override
  State<PremiumDiaryScreen> createState() => _DiaryScreenState();
}

class _PremiumDiaryScreenState extends State<PremiumDiaryScreen> {
  static const _storageKey = 'diary_entries';
  static const _accent = Color(0xFFFF824F);
  static const _categories = <String>[
    'Geral',
    'Estudos',
    'Trabalho',
    'Pessoal',
    'Treino',
    'Metas',
    'Conquista',
    'Dificuldade',
    'Ideia',
    'Aprendizado',
  ];
  static const _moods = <String, IconData>{
    'Muito ruim': Icons.sentiment_very_dissatisfied_outlined,
    'Ruim': Icons.sentiment_dissatisfied_outlined,
    'Normal': Icons.sentiment_neutral_outlined,
    'Bem': Icons.sentiment_satisfied,
    'Muito bem': Icons.sentiment_very_satisfied_outlined,
  };

  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _entries = [];
  DateTime _selectedDate = DateTime.now();
  String _category = 'Geral';
  String _mood = 'Normal';
  String? _editingId;
  String _filter = 'Todos';
  bool _searching = false;
  bool _loading = true;

  String _dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String _weekdayLabel(DateTime date) =>
      DateFormat('EEEE', 'pt_BR').format(date);

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final values = await StorageService.read(_storageKey);
    if (!mounted) return;
    setState(() {
      _entries = values;
      _entries.sort(_compareEntries);
      _loading = false;
    });
  }

  int _compareEntries(Map<String, dynamic> a, Map<String, dynamic> b) {
    final first = (a['createdAt'] ?? '').toString();
    final second = (b['createdAt'] ?? '').toString();
    return second.compareTo(first);
  }

  Future<void> _persist() async {
    _entries.sort(_compareEntries);
    await StorageService.write(_storageKey, _entries);
  }

  List<Map<String, dynamic>> get _selectedDayEntries => _entries
      .where((entry) => entry['date'] == _dayKey(_selectedDate))
      .toList()
    ..sort(_compareEntries);

  List<Map<String, dynamic>> get _visibleEntries {
    final query = _searchController.text.trim().toLowerCase();
    return _entries.where((entry) {
      if (_filter == 'Favoritos' && entry['favorite'] != true) return false;
      if (_filter != 'Todos' &&
          _filter != 'Favoritos' &&
          entry['category'] != _filter) {
        return false;
      }
      if (query.isEmpty) return true;
      final searchable = [
        entry['title'],
        entry['body'],
        entry['category'],
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList()
      ..sort(_compareEntries);
  }

  void _clearEditor() {
    _editingId = null;
    _titleController.clear();
    _bodyController.clear();
    _category = 'Geral';
    _mood = 'Normal';
  }

  void _newEntry({String? category, String? mood}) {
    setState(() {
      _clearEditor();
      if (category != null) _category = category;
      if (mood != null) _mood = mood;
    });
    _showEditor();
  }

  void _editEntry(Map<String, dynamic> entry) {
    setState(() {
      _editingId = entry['id'].toString();
      _titleController.text = (entry['title'] ?? '').toString();
      _bodyController.text = (entry['body'] ?? '').toString();
      _category = (entry['category'] ?? 'Geral').toString();
      _mood = (entry['mood'] ?? 'Normal').toString();
      _selectedDate =
          DateTime.tryParse((entry['date'] ?? '').toString()) ?? DateTime.now();
    });
    _showEditor();
  }

  Future<void> _showEditor() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editingId == null
                              ? 'Nova anotação'
                              : 'Editar anotação',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salvar anotação',
                        onPressed: () async {
                          final didSave = await _saveEntry();
                          if (didSave && context.mounted) {
                            Navigator.pop(sheetContext, true);
                          }
                        },
                        icon: const Icon(Icons.check_circle,
                            color: _accent, size: 32),
                      ),
                    ],
                  ),
                  Text(
                    '${DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR').format(_selectedDate)} • ${_weekdayLabel(_selectedDate)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Título (opcional)',
                      hintText: 'Dê um nome para este momento',
                      prefixIcon: Icon(Icons.short_text),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bodyController,
                    autofocus: true,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: 5000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Como foi esse momento?',
                      hintText:
                          'Escreva sobre seus pensamentos, conquistas, dificuldades, ideias e aprendizados...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Categoria', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      return ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) {
                          setState(() => _category = category);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Como você estava se sentindo?',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moods.entries.map((item) {
                      return ChoiceChip(
                        avatar: Icon(item.value, size: 18),
                        label: Text(item.key),
                        selected: _mood == item.key,
                        onSelected: (_) {
                          setState(() => _mood = item.key);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final didSave = await _saveEntry();
                        if (didSave && context.mounted) {
                          Navigator.pop(sheetContext, true);
                        }
                      },
                      icon: const Icon(Icons.edit_note),
                      label: Text(_editingId == null
                          ? 'Salvar anotação'
                          : 'Salvar alterações'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<bool> _saveEntry() async {
    final body = _bodyController.text.trim();
    final title = _titleController.text.trim();
    if (body.isEmpty && title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algo antes de salvar.')),
      );
      return false;
    }
    final now = DateTime.now();
    final id = _editingId ?? now.microsecondsSinceEpoch.toString();
    final existingIndex = _entries.indexWhere((entry) => entry['id'] == id);
    final previous = existingIndex >= 0 ? _entries[existingIndex] : null;
    final entry = <String, dynamic>{
      'id': id,
      'date': _dayKey(_selectedDate),
      'title': title.isEmpty ? _defaultTitle(body) : title,
      'body': body,
      'category': _category,
      'mood': _mood,
      'favorite': previous?['favorite'] == true,
      'createdAt': previous?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };
    setState(() {
      if (existingIndex >= 0) {
        _entries[existingIndex] = entry;
      } else {
        _entries.add(entry);
      }
      _entries.sort(_compareEntries);
      _clearEditor();
    });
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previous == null ? 'Anotação salva.' : 'Anotação atualizada.'),
        ),
      );
    }
    return true;
  }

  String _defaultTitle(String body) {
    final firstLine = body.split('\n').first.trim();
    if (firstLine.length <= 36) return firstLine;
    return '${firstLine.substring(0, 33)}...';
  }

  Future<void> _toggleFavorite(Map<String, dynamic> entry) async {
    final index = _entries.indexWhere((item) => item['id'] == entry['id']);
    if (index < 0) return;
    setState(() {
      _entries[index]['favorite'] = _entries[index]['favorite'] != true;
    });
    await _persist();
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir anotação?'),
        content: const Text('Esta anotação será removida permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _entries.removeWhere((item) => item['id'] == entry['id']));
    await _persist();
  }

  Widget _buildWeekStrip() {
    final today = DateTime.now();
    final start = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    return Row(
      children: days.map((day) {
        final selected = _dayKey(day) == _dayKey(_selectedDate);
        final isToday = _dayKey(day) == _dayKey(today);
        final hasEntries = _entries.any((entry) => entry['date'] == _dayKey(day));
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              _selectedDate = day;
              _clearEditor();
            }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEE', 'pt_BR').format(day).replaceAll('.', ''),
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.black : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Colors.black : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: hasEntries
                          ? (selected ? Colors.black : _accent)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (isToday)
                    Text(
                      'Hoje',
                      style: TextStyle(
                        fontSize: 9,
                        color: selected ? Colors.black : _accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMoodPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Como você está se sentindo hoje?',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: _moods.entries.map((item) {
            final selected = _selectedDayEntries.any((entry) => entry['mood'] == item.key);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _newEntry(category: 'Pessoal', mood: item.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected ? _accent.withValues(alpha: .18) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _accent : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(item.value, size: 23,
                            color: selected ? _accent : null),
                        const SizedBox(height: 4),
                        Text(
                          item.key,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final mood = (entry['mood'] ?? 'Normal').toString();
    final category = (entry['category'] ?? 'Geral').toString();
    final createdAt = DateTime.tryParse((entry['createdAt'] ?? '').toString());
    final time = createdAt == null ? '' : DateFormat('HH:mm').format(createdAt);
    final body = (entry['body'] ?? '').toString();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _editEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notes_outlined, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (entry['title'] ?? 'Anotação').toString(),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(time, style: Theme.of(context).textTheme.labelSmall),
                  IconButton(
                    tooltip: entry['favorite'] == true
                        ? 'Remover dos favoritos'
                        : 'Favoritar',
                    onPressed: () => _toggleFavorite(entry),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      entry['favorite'] == true ? Icons.star : Icons.star_border,
                      color: entry['favorite'] == true ? _accent : null,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opções da anotação',
                    onSelected: (value) {
                      if (value == 'edit') _editEntry(entry);
                      if (value == 'delete') _deleteEntry(entry);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ],
              ),
              if (body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                  child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
                ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _tag(category),
                  _tag(mood),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );

  Widget _summaryTile(IconData icon, String title, String category) {
    final count = _entries.where((entry) => entry['category'] == category).length;
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _newEntry(category: category),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: _accent, size: 25),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.bodySmall),
                      Text('$count', style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayEntries = _selectedDayEntries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Diário', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Pesquisar anotações',
            onPressed: () => setState(() => _searching = !_searching),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _buildWeekStrip(),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny_outlined, color: _accent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _dayKey(_selectedDate) == _dayKey(DateTime.now())
                                    ? 'Hoje'
                                    : DateFormat('d MMMM', 'pt_BR').format(_selectedDate),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(DateFormat("d 'de' MMM", 'pt_BR').format(_selectedDate)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Como foi seu dia?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dayEntries.isEmpty
                              ? 'Escreva sobre o que quiser: pensamentos, conquistas, dificuldades, ideias, aprendizados...'
                              : '${dayEntries.length} anotação(ões) salva(s) neste dia.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .72),
                              ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: () => _newEntry(),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Escrever anotação de hoje'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (dayEntries.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Anotações do dia',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _newEntry(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nova'),
                      ),
                    ],
                  ),
                  ...dayEntries.map(_buildEntryCard),
                ],
                const SizedBox(height: 18),
                _buildMoodPicker(),
                const SizedBox(height: 18),
                Text('Resumo rápido',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(children: [
                  _summaryTile(Icons.emoji_events_outlined, 'Conquistas', 'Conquista'),
                  _summaryTile(Icons.track_changes_outlined, 'Dificuldades', 'Dificuldade'),
                ]),
                Row(children: [
                  _summaryTile(Icons.lightbulb_outline, 'Ideias', 'Ideia'),
                  _summaryTile(Icons.menu_book_outlined, 'Aprendizados', 'Aprendizado'),
                ]),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Meus registros',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text('${_entries.length} registro(s)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar anotações...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in ['Todos', 'Favoritos', ..._categories])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_visibleEntries.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.auto_stories_outlined, size: 36),
                          const SizedBox(height: 8),
                          Text(_entries.isEmpty
                              ? 'Suas anotações aparecerão aqui.'
                              : 'Nenhuma anotação encontrada.'),
                        ],
                      ),
                    ),
                  )
                else
                  ..._visibleEntries.map(_buildEntryCard),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _accent,
        foregroundColor: Colors.black,
        tooltip: 'Nova anotação',
        onPressed: () => _newEntry(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
