import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeScreen extends StatefulWidget {
  final ThemeSettings initialSettings;
  final ValueChanged<ThemeSettings>? onSettingsChanged;
  const ThemeScreen({super.key, required this.initialSettings, this.onSettingsChanged});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  late ThemeSettings settings;
  static const colors = <Color>[
    Color(0xFFF7F5FA), Color(0xFFE8F5E9), Color(0xFFE3F2FD),
    Color(0xFFFFF3E0), Color(0xFFFCE4EC), Color(0xFFEDE7F6),
    Color(0xFFE0F2F1), Color(0xFFFFFDE7), Color(0xFF263238),
    Color(0xFF37474F), Color(0xFF3F51B5), Color(0xFF00695C),
  ];

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings;
  }

  Future<void> _save(ThemeSettings next) async {
    setState(() => settings = next);
    widget.onSettingsChanged?.call(next);
    await ThemeService.save(next);
  }

  Future<void> _pickImage() async {
    final path = await ThemeService.pickAndPersistImage();
    if (path == null || !mounted) return;
    await _save(settings.copyWith(imagePath: path));
  }

  Future<void> _clearImage() async {
    await _save(settings.copyWith(clearImagePath: true));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = settings.imagePath != null;
    return PopScope<ThemeSettings>(
      onPopInvokedWithResult: (_, __) => widget.onSettingsChanged?.call(settings),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar tema'),
        leading: IconButton(onPressed: () => Navigator.pop(context, settings), icon: const Icon(Icons.arrow_back)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Cor de fundo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((color) {
              final selected = !hasImage && settings.backgroundColorValue == color.value;
              return InkWell(
                onTap: () => _save(settings.copyWith(backgroundColorValue: color.value, clearImagePath: true)),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? Theme.of(context).colorScheme.primary : Colors.black12,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: selected ? Icon(Icons.check, color: color.computeLuminance() > .55 ? Colors.black : Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Foto personalizada', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(hasImage ? 'Sua foto está aplicada ao fundo do app.' : 'Escolha uma foto da galeria para usar como fundo.'),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(hasImage ? 'Trocar foto' : 'Usar minha foto'),
                ),
                if (hasImage) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(onPressed: _clearImage, icon: const Icon(Icons.close), label: const Text('Remover foto')),
                  const SizedBox(height: 12),
                  _slider('Zoom', settings.scale, .5, 3, (v) => settings.copyWith(scale: v)),
                  _slider('Posição horizontal', settings.x, -5, 5, (v) => settings.copyWith(x: v)),
                  _slider('Posição vertical', settings.y, -5, 5, (v) => settings.copyWith(y: v)),
                  _slider('Transparência da foto', settings.opacity, .05, 1, (v) => settings.copyWith(opacity: v)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Tema aplicado no app inteiro'), subtitle: Text('O tema é salvo automaticamente e usado em todas as áreas do Polirotinas.'))),
        ],
      ),
    ));
  }

  Widget _slider(String label, double value, double min, double max, ThemeSettings Function(double) next) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value.toStringAsFixed(2))]),
      Slider(value: value, min: min, max: max, divisions: 20, onChanged: (v) => _save(next(v))),
    ]);
  }
}
