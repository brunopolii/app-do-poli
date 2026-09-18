import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/activation_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/food_screen.dart';
import 'screens/gym_screen.dart';
import 'screens/home_screen.dart';
import 'screens/theme_screen.dart';
import 'services/license_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await NotificationService.initialize();
  final activated = await LicenseService().isActivated();
  final settings = await ThemeService.load();
  final prefs = await SharedPreferences.getInstance();
  runApp(AppDoPoli(
    initiallyActivated: activated,
    initialTheme: settings,
    initialThemeMode: prefs.getString('theme_mode') ?? 'system',
  ));
}

class _AppBackground extends StatefulWidget {
  final ThemeSettings settings;
  final Widget child;

  const _AppBackground({
    required this.settings,
    required this.child,
  });

  @override
  State<_AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<_AppBackground> {
  ImageProvider? _image;
  String? _path;

  @override
  void initState() {
    super.initState();
    _setImage(widget.settings.imagePath);
  }

  @override
  void didUpdateWidget(covariant _AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.imagePath != _path) {
      _setImage(widget.settings.imagePath);
    }
  }

  void _setImage(String? path) {
    if (path == null || !File(path).existsSync()) {
      if (mounted) {
        setState(() {
          _path = null;
          _image = null;
        });
      }
      return;
    }

    final provider = FileImage(File(path));
    _path = path;
    _precacheAndShow(provider);
  }

  Future<void> _precacheAndShow(ImageProvider provider) async {
    try {
      await precacheImage(provider, context);
    } catch (_) {
      // Keep the current background if the new image cannot be decoded.
      return;
    }
    if (!mounted) return;
    setState(() => _image = provider);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final configured = Color(s.backgroundColorValue);
    final base = dark ? theme.colorScheme.surface : configured;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        if (_image != null)
          IgnorePointer(
            child: ClipRect(
              child: Opacity(
                opacity: s.opacity,
                child: Transform.translate(
                  offset: Offset(s.x * 40, s.y * 40),
                  child: Transform.scale(
                    scale: s.scale,
                    child: Image(
                      image: _image!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        s.imagePath != null && _image == null
            ? const SizedBox.shrink()
            : const SizedBox.shrink(),
        widget.child,
      ],
    );
  }
}


class AppDoPoli extends StatefulWidget {
  final bool initiallyActivated;
  final ThemeSettings initialTheme;
  final String initialThemeMode;
  const AppDoPoli({super.key, required this.initiallyActivated, required this.initialTheme, required this.initialThemeMode});
  @override State<AppDoPoli> createState() => _AppDoPoliState();
}

class _AppDoPoliState extends State<AppDoPoli> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<GymScreenState> _gymKey = GlobalKey<GymScreenState>();
  late bool activated;
  late ThemeSettings themeSettings;
  late ThemeMode themeMode;
  int selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    activated = widget.initiallyActivated;
    themeSettings = widget.initialTheme;
    themeMode = switch (widget.initialThemeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  void _finishActivation() => setState(() => activated = true);

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: _navigatorKey.currentContext ?? context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajuda'),
        content: const Text(
          'Precisa de ajuda ou encontrou algum problema no Poliroutines?\n\n'
          'Entre em contato pelo e-mail:\n'
          'brunopolineg@gmail.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTheme() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final result = await navigator.push<ThemeEditResult>(
      MaterialPageRoute(
        builder: (_) => ThemeScreen(
          initialSettings: themeSettings,
          initialMode: themeMode,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      themeSettings = result.settings;
      themeMode = result.mode;
    });
  }

  Future<void> _toggleTheme() async {
    final next = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', next == ThemeMode.dark ? 'dark' : 'light');
    if (mounted) setState(() => themeMode = next);
  }

  Widget _background(BuildContext context, Widget child) {
    return _AppBackground(
      settings: themeSettings,
      child: child,
    );
  }

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final seed = dark ? const Color(0xFF9B82DB) : const Color(0xFF6750A4);
    final cardBase = themeSettings.cardColorValue == 0
        ? (dark ? const Color(0xFF1F1F24) : const Color(0xFFFFFFFF))
        : Color(themeSettings.cardColorValue);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorSchemeSeed: themeSettings.accentColorValue == 0 ? seed : Color(themeSettings.accentColorValue),
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
      cardTheme: CardThemeData(
        color: cardBase.withValues(alpha: themeSettings.cardOpacity),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20)), side: BorderSide(color: Color(themeSettings.cardBorderColorValue), width: 1)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF2A2A31) : Colors.white,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(width: 2, color: dark ? const Color(0xFFB69BFF) : const Color(0xFF6750A4)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Poliroutines',
    navigatorKey: _navigatorKey,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: themeMode,
    builder: (context, child) => _background(context, child ?? const SizedBox.shrink()),
    home: activated
        ? Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('Polirotinas', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  tooltip: 'Personalizar tema',
                  onPressed: _openTheme,
                  icon: const Icon(Icons.palette_outlined),
                ),
                IconButton(
                  tooltip: 'Ajuda',
                  onPressed: _showHelp,
                  icon: const Icon(Icons.help_outline),
                ),
                IconButton(
                  tooltip: 'Modo claro/escuro',
                  onPressed: _toggleTheme,
                  icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
              ],
            ),
            body: IndexedStack(
              index: selectedIndex,
              children: [
                const AgendaScreen(),
                GymScreen(key: _gymKey),
                HomeScreen(key: _homeKey, onOpenTheme: _openTheme),
                const FoodScreen(),
                const FinanceScreen(),
              ],
            ),
            bottomNavigationBar: Builder(
              builder: (context) {
                final navBase = themeSettings.navColorValue == 0
                    ? Theme.of(context).colorScheme.surface
                    : Color(themeSettings.navColorValue);
                final navContent =
                    navBase.computeLuminance() > .48 ? Colors.black87 : Colors.white;
                final accent = Color(
                  themeSettings.accentColorValue == 0
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? 0xFF9B82DB
                          : 0xFF6750A4)
                      : themeSettings.accentColorValue,
                );
                return NavigationBarTheme(
                  data: NavigationBarThemeData(
                    backgroundColor:
                        navBase.withValues(alpha: themeSettings.navOpacity),
                    indicatorColor: accent,
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        color: selected
                            ? (accent.computeLuminance() > .48
                                ? Colors.black87
                                : Colors.white)
                            : navContent,
                      );
                    }),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        color: selected
                            ? (accent.computeLuminance() > .48
                                ? Colors.black87
                                : Colors.white)
                            : navContent,
                      );
                    }),
                    overlayColor:
                        WidgetStatePropertyAll(navContent.withValues(alpha: .08)),
                  ),
                  child: NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (i) {
                      setState(() => selectedIndex = i);
                      if (i == 1) _gymKey.currentState?.refresh();
                      if (i == 2) _homeKey.currentState?.refresh();
                    },
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: 'Agenda',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.fitness_center_outlined),
                        selectedIcon: Icon(Icons.fitness_center),
                        label: 'Academia',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Início',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.restaurant_outlined),
                        selectedIcon: Icon(Icons.restaurant),
                        label: 'Alimentação',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet),
                        label: 'Financeiro',
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        : ActivationScreen(onActivated: _finishActivation),
  );
}
