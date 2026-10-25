import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/premium_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/premium_diary_screen.dart';
import 'screens/food_screen.dart';
import 'screens/gym_screen.dart';
import 'screens/home_screen.dart';
import 'screens/theme_screen.dart';
import 'services/license_service.dart';
import 'services/plan_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await NotificationService.initialize();
  await LicenseService().initialize();
  final settings = await ThemeService.load();
  final prefs = await SharedPreferences.getInstance();
  runApp(AppDoPoli(
    initialTheme: settings,
    initialThemeMode: prefs.getString('theme_mode') ?? 'system',
  ));
}

class _AppBackground extends StatefulWidget {
  final ThemeSettings settings;
  final ValueChanged<ThemeSettings> onSettingsChanged;
  final Widget child;

  const _AppBackground({
    required this.settings,
    required this.onSettingsChanged,
    required this.child,
  });

  @override
  State<_AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<_AppBackground> {
  ImageProvider? _image;
  Size? _sourceSize;
  String? _path;

  @override
  void initState() {
    super.initState();
    _setImage(widget.settings.imagePath);
  }

  @override
  void didUpdateWidget(covariant _AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.imagePath != oldWidget.settings.imagePath) {
      _setImage(widget.settings.imagePath);
    }
  }

  void _setImage(String? path) {
    if (path == null || !File(path).existsSync()) {
      if (mounted) {
        setState(() {
          _path = null;
          _image = null;
          _sourceSize = null;
        });
      }
      return;
    }
    if (_path == path && _image != null) return;
    final provider = FileImage(File(path));
    _path = path;
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, synchronousCall) {
      stream.removeListener(listener);
      if (!mounted) return;
      setState(() {
        _image = provider;
        _sourceSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    }, onError: (error, stackTrace) {
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  void _panBackground(Offset delta, Size viewport, Size imageSize) {
    final fitScale = (viewport.width / imageSize.width)
        .clamp(0.0, double.infinity).toDouble();
    final coverScale = (viewport.height / imageSize.height)
        .clamp(0.0, double.infinity);
    final baseScale = fitScale > coverScale ? fitScale : coverScale;
    final scale = baseScale * widget.settings.scale.clamp(1.0, 3.0).toDouble().toDouble();
    final overflowX = ((imageSize.width * scale) - viewport.width) / 2;
    final overflowY = ((imageSize.height * scale) - viewport.height) / 2;
    final currentX = overflowX <= 0 ? 0.0 : widget.settings.x * overflowX;
    final currentY = overflowY <= 0 ? 0.0 : widget.settings.y * overflowY;
    final nextX = overflowX <= 0
        ? 0.0
        : ((currentX + delta.dx).clamp(-overflowX, overflowX)) / overflowX;
    final nextY = overflowY <= 0
        ? 0.0
        : ((currentY + delta.dy).clamp(-overflowY, overflowY)) / overflowY;
    widget.onSettingsChanged(widget.settings.copyWith(x: nextX, y: nextY));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final configured = Color(s.backgroundColorValue);
    final base = dark ? theme.colorScheme.surface : configured;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final source = _sourceSize;
        Widget background = ColoredBox(color: base);
        if (_image != null && source != null && viewport.width > 0 && viewport.height > 0) {
          final coverScale = (viewport.width / source.width)
              .clamp(0.0, double.infinity);
          final coverHeightScale = (viewport.height / source.height)
              .clamp(0.0, double.infinity);
          final baseScale = coverScale > coverHeightScale ? coverScale : coverHeightScale;
          final scale = baseScale * s.scale.clamp(1.0, 3.0);
          final imageWidth = source.width * scale;
          final imageHeight = source.height * scale;
          final overflowX = ((imageWidth - viewport.width) / 2).clamp(0.0, double.infinity);
          final overflowY = ((imageHeight - viewport.height) / 2).clamp(0.0, double.infinity);
          final offsetX = overflowX * s.x.clamp(-1.0, 1.0).toDouble();
          final offsetY = overflowY * s.y.clamp(-1.0, 1.0).toDouble();
          background = ClipRect(
            child: Opacity(
              opacity: s.opacity.clamp(0.05, 1.0).toDouble(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) => _panBackground(details.delta, viewport, source),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      width: imageWidth,
                      height: imageHeight,
                      left: (viewport.width - imageWidth) / 2 + offsetX,
                      top: (viewport.height - imageHeight) / 2 + offsetY,
                      child: Image(
                        image: _image!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            background,
            widget.child,
          ],
        );
      },
    );
  }
}

class AppDoPoli extends StatefulWidget {
  final ThemeSettings initialTheme;
  final String initialThemeMode;
  const AppDoPoli({super.key, required this.initialTheme, required this.initialThemeMode});
  @override State<AppDoPoli> createState() => _AppDoPoliState();
}

class _AppDoPoliState extends State<AppDoPoli> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<AgendaScreenState> _agendaKey = GlobalKey<AgendaScreenState>();
  final GlobalKey<GymScreenState> _gymKey = GlobalKey<GymScreenState>();
  final GlobalKey<FoodScreenState> _foodKey = GlobalKey<FoodScreenState>();
  final GlobalKey<FinanceScreenState> _financeKey = GlobalKey<FinanceScreenState>();
  bool agendaOnly = false;
  late ThemeSettings themeSettings;
  late ThemeMode themeMode;
  int selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _refreshPlanAccess();
    themeSettings = widget.initialTheme;
    themeMode = switch (widget.initialThemeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  void _finishActivation() {
    _navigatorKey.currentState?.pop();
    _refreshPlanAccess();
  }

  Future<void> _refreshPlanAccess() async {
    final restricted = await PlanService().agendaOnly;
    if (mounted) setState(() => agendaOnly = restricted);
  }

  Future<void> _openDiary() async {
    final premium = await PlanService().hasPremium;
    if (!mounted) return;
    await _navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => premium
            ? const PremiumDiaryScreen()
            : const DiaryScreen(),
      ),
    );
  }

  Future<void> _showPremium() async {
    await _navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(onActivated: _finishActivation),
      ),
    );
    await _refreshPlanAccess();
  }

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
      onSettingsChanged: (next) {
        setState(() => themeSettings = next);
        ThemeService.save(next);
      },
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
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('pt', 'BR')],
    navigatorKey: _navigatorKey,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: themeMode,
    builder: (context, child) => _background(context, child ?? const SizedBox.shrink()),
    home: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('Poliroutines', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                if (!agendaOnly) IconButton(
                  tooltip: 'Diário',
                  onPressed: _openDiary,
                  icon: const Icon(Icons.menu_book_outlined),
                ),
                TextButton.icon(onPressed: _showPremium, icon: const Icon(Icons.workspace_premium_outlined), label: const Text('Premium')),
                if (!agendaOnly) IconButton(
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
            body: agendaOnly
                ? const AgendaScreen()
                : IndexedStack(
              index: selectedIndex,
              children: [
                AgendaScreen(key: _agendaKey),
                GymScreen(key: _gymKey),
                HomeScreen(
                  key: _homeKey,
                  onOpenTheme: _openTheme,
                  onNavigate: (index) => setState(() => selectedIndex = index),
                  onQuickAgenda: () => _agendaKey.currentState?.openQuickAdd(),
                  onQuickWorkout: () => _gymKey.currentState?.openQuickWorkout(),
                  onQuickMeal: () => _foodKey.currentState?.openQuickAdd(),
                  onQuickFinance: () => _financeKey.currentState?.openQuickAdd(),
                ),
                FoodScreen(key: _foodKey),
                FinanceScreen(key: _financeKey),
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
                      if (agendaOnly && i != 0) { _showPremium(); return; }
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
          ),
  );
}
