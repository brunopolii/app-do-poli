import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeCardSettings {
  static const storageKey = 'home_cards_v1';

  static List<Map<String, dynamic>> defaults() => [
    {'id': 'overview', 'type': 'overview', 'title': 'Resumo de hoje', 'visible': true, 'size': 'normal', 'metrics': ['agenda', 'gym', 'food']},
    {'id': 'quick', 'type': 'quick', 'title': 'Ações rápidas', 'visible': true, 'size': 'compact', 'metrics': ['agenda', 'gym', 'food', 'finance']},
    {'id': 'agenda', 'type': 'agenda', 'title': 'Próximos compromissos', 'visible': true, 'size': 'normal', 'metrics': ['next']},
    {'id': 'gym', 'type': 'gym', 'title': 'Academia', 'visible': true, 'size': 'normal', 'metrics': ['workouts', 'last']},
    {'id': 'food', 'type': 'food', 'title': 'Alimentação de hoje', 'visible': true, 'size': 'normal', 'metrics': ['calories', 'protein', 'carbs', 'fat']},
    {'id': 'finance', 'type': 'finance', 'title': 'Financeiro do mês', 'visible': true, 'size': 'normal', 'metrics': ['income', 'expense', 'balance']},
    {'id': 'alerts', 'type': 'alerts', 'title': 'Atenção hoje', 'visible': true, 'size': 'normal', 'metrics': ['appointments', 'bills']},
    {'id': 'weekly', 'type': 'weekly', 'title': 'Relatório semanal', 'visible': true, 'size': 'normal', 'metrics': ['workouts', 'meals', 'finance']},
  ];

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return defaults();
    try {
      final decoded = jsonDecode(raw) as List;
      final cards = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (cards.isEmpty) return defaults();
      return cards;
    } catch (_) {
      return defaults();
    }
  }

  static Future<void> save(List<Map<String, dynamic>> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(cards));
  }
}

const homeCardTypes = <String, String>{
  'overview': 'Resumo do dia',
  'quick': 'Ações rápidas',
  'agenda': 'Compromissos',
  'gym': 'Academia',
  'food': 'Alimentação',
  'finance': 'Financeiro',
  'alerts': 'Alertas',
  'weekly': 'Relatório semanal',
};

class HomeCustomizationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialCards;
  const HomeCustomizationScreen({super.key, required this.initialCards});

  @override
  State<HomeCustomizationScreen> createState() => _HomeCustomizationScreenState();
}

class _HomeCustomizationScreenState extends State<HomeCustomizationScreen> {
  late List<Map<String, dynamic>> cards;

  @override
  void initState() {
    super.initState();
    cards = widget.initialCards.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _save() async {
    await HomeCardSettings.save(cards);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    setState(() => cards = HomeCardSettings.defaults());
    await HomeCardSettings.save(cards);
  }

  void _addCard() {
    String type = 'agenda';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar cartão'),
          content: DropdownButtonFormField<String>(
            value: type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Conteúdo'),
            items: homeCardTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) { if (value != null) setDialogState(() => type = value); },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final id = '${type}_${DateTime.now().microsecondsSinceEpoch}';
                setState(() => cards.add({
                  'id': id,
                  'type': type,
                  'title': homeCardTypes[type] ?? 'Cartão',
                  'visible': true,
                  'size': 'normal',
                  'metrics': _defaultMetrics(type),
                }));
                Navigator.pop(dialogContext);
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _defaultMetrics(String type) => switch (type) {
    'overview' => ['agenda', 'gym', 'food'],
    'quick' => ['agenda', 'gym', 'food', 'finance'],
    'agenda' => ['next'],
    'gym' => ['workouts', 'last'],
    'food' => ['calories', 'protein', 'carbs', 'fat'],
    'finance' => ['income', 'expense', 'balance'],
    'alerts' => ['appointments', 'bills'],
    _ => ['workouts', 'meals', 'finance'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalizar início')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Ative, organize e ajuste os cartões que aparecem na tela inicial. Você pode adicionar mais de um cartão do mesmo módulo.', style: TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = cards.removeAt(oldIndex);
                cards.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final card = cards[index];
              final type = (card['type'] ?? 'overview').toString();
              final visible = card['visible'] != false;
              final size = (card['size'] ?? 'normal').toString();
              return Card(
                key: ValueKey(card['id']),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.drag_handle),
                          const SizedBox(width: 8),
                          Expanded(child: Text((card['title'] ?? homeCardTypes[type] ?? 'Cartão').toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                          Switch(value: visible, onChanged: (v) => setState(() => card['visible'] = v)),
                          IconButton(
                            tooltip: 'Remover cartão',
                            onPressed: () => setState(() => cards.removeAt(index)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Tamanho'),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'compact', label: Text('Compacto')),
                                ButtonSegment(value: 'normal', label: Text('Normal')),
                                ButtonSegment(value: 'large', label: Text('Grande')),
                              ],
                              selected: {size},
                              onSelectionChanged: (value) => setState(() => card['size'] = value.first),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: (card['title'] ?? '').toString(),
                        decoration: const InputDecoration(labelText: 'Título do cartão', isDense: true),
                        onChanged: (value) => card['title'] = value,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          OutlinedButton.icon(onPressed: _addCard, icon: const Icon(Icons.add), label: const Text('Adicionar cartão')),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _reset, icon: const Icon(Icons.restart_alt), label: const Text('Restaurar padrão')),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Salvar personalização')),
        ],
      ),
    );
  }
}
