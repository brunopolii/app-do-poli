import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  final themeSettings = await ThemeService.load();
  runApp(AppDoPoli(initiallyActivated: activated, initialTheme: themeSettings));
}

class AppDoPoli extends StatefulWidget {
  final bool initiallyActivated;
  final ThemeSettings initialTheme;

  const AppDoPoli({
    super.key,
    required this.initiallyActivated,
    required this.initialTheme,
  });

  @override
  State<AppDoPoli> createState() => _AppDoPoliState();
}

class _AppDoPoliState extends State<AppDoPoli> {
  late bool activated;
  late ThemeSettings themeSettings;
  int selectedIndex = 2;
  ThemeMode themeMode = ThemeMode.system;
  int homeRefresh = 0;

  @override
  void initState() {
    super.initState();
    activated = widget.initiallyActivated;
    themeSettings = widget.initialTheme;
  }

  void _finishActivation() {
    setState(() => activated = true);
  }

  Future<void> _openTheme(BuildContext navigationContext) async {
    final result = await Navigator.of(navigationContext).push<ThemeSettings>(
      MaterialPageRoute(
        builder: (_) => ThemeScreen(
          initialSettings: themeSettings,
          onSettingsChanged: (settings) {
            if (mounted) setState(() => themeSettings = settings);
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => themeSettings = result);
  }

  Widget _globalBackground(BuildContext context, Widget child) {
    final settings = themeSettings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Color.alphaBlend(Colors.black.withValues(alpha: .72), Color(settings.backgroundColorValue))
        : Color(settings.backgroundColorValue);
    final imagePath = settings.imagePath;

    if (imagePath == null) {
      return ColoredBox(color: backgroundColor, child: child);
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      return ColoredBox(color: backgroundColor, child: child);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: backgroundColor),
        IgnorePointer(
          child: ClipRect(
            child: Opacity(
              opacity: settings.opacity,
              child: Transform.translate(
                offset: Offset(settings.x * 40, settings.y * 40),
                child: Transform.scale(
                  scale: settings.scale,
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isDark) IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: .38))),
        child,
      ],
    );
  }

  ThemeData _buildLightTheme() {
    const seed = Color(0xFF6750A4);
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(color: Colors.white.withValues(alpha: .93), elevation: 1, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: Colors.white.withValues(alpha: .98)),
      popupMenuTheme: const PopupMenuThemeData(color: Color(0xFFFFFBFF)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(width: 2, color: seed),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF9B82DB), brightness: Brightness.dark);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(color: const Color(0xFF1D1B20).withValues(alpha: .96), elevation: 1, surfaceTintColor: Colors.transparent),
      dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF242127), surfaceTintColor: Colors.transparent),
      popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF242127)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2B2930),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Polirotinas',
      themeMode: themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      builder: (context, child) => _globalBackground(context, child ?? const SizedBox.shrink()),
      home: activated ? Builder(builder: (appContext) => Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: const Text(
                  'Polirotinas',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Personalizar tema',
                    onPressed: () => _openTheme(appContext),
                    icon: const Icon(Icons.palette_outlined),
                  ),
                  IconButton(
                    tooltip: 'Alternar tema',
                    onPressed: () => setState(
                      () => themeMode = themeMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    ),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
              ),
              body: IndexedStack(
                index: selectedIndex,
                children: [
                  const AgendaScreen(),
                  const GymScreen(),
                  HomeScreen(key: ValueKey('home-$homeRefresh')),
                  const FoodScreen(),
                  const FinanceScreen(),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                backgroundColor: Theme.of(appContext).colorScheme.surface.withValues(alpha: .92),
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) => setState(() {
                  selectedIndex = i;
                  homeRefresh++;
                }),
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
            ))
          : ActivationScreen(onActivated: _finishActivation),
    );
  }
}
