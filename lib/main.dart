import 'package:flutter/material.dart';
import 'screens/agenda_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/food_screen.dart';
import 'screens/gym_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const AppDoPoli());
}

class AppDoPoli extends StatefulWidget {
  const AppDoPoli({super.key});
  @override State<AppDoPoli> createState() => _AppDoPoliState();
}

class _AppDoPoliState extends State<AppDoPoli> {
  int selectedIndex = 1;
  ThemeMode themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App do Poli',
      themeMode: themeMode,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6750A4), scaffoldBackgroundColor: const Color(0xFFF7F6FA)),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: const Color(0xFF9B82DB)),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('App do Poli', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'Alternar tema',
              onPressed: () => setState(() => themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
              icon: const Icon(Icons.dark_mode_outlined),
            ),
          ],
        ),
        body: IndexedStack(index: selectedIndex, children: const [AgendaScreen(), HomeScreen(), GymScreen(), FoodScreen(), FinanceScreen()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => setState(() => selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Agenda'),
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
            NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Academia'),
            NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Alimentação'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Financeiro'),
          ],
        ),
      ),
    );
  }
}
