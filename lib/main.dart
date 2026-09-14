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

  Future<void> _openTheme() async {
    final result = await Navigator.of(context).push<ThemeSettings>(
      MaterialPageRoute(
        builder: (_) => ThemeScreen(initialSettings: themeSettings),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => themeSettings = result);
  }

  Widget _globalBackground(Widget child) {
    final settings = themeSettings;
    final backgroundColor = Color(settings.backgroundColorValue);
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
        child,
      ],
    );
  }

  ThemeData _buildLightTheme() {
    const seed = Color(0xFF6750A4);
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF9B82DB),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
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
      builder: (context, child) => _globalBackground(
        child ?? const SizedBox.shrink(),
      ),
      home: activated
          ? Scaffold(
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
                    onPressed: _openTheme,
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
                backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
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
            )
          : ActivationScreen(onActivated: _finishActivation),
    );
  }
}
