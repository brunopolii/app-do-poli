import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/agenda_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/food_screen.dart';
import 'screens/gym_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await initializeDateFormatting('pt_BR'); await NotificationService.initialize(); runApp(const AppDoPoli()); }

class AppDoPoli extends StatefulWidget { const AppDoPoli({super.key}); @override State<AppDoPoli> createState()=>_AppDoPoliState(); }
class _AppDoPoliState extends State<AppDoPoli>{int selectedIndex=2;ThemeMode themeMode=ThemeMode.system;int homeRefresh=0;
  @override Widget build(BuildContext context){const seed=Color(0xFF6750A4);return MaterialApp(debugShowCheckedModeBanner:false,title:'App do Poli',themeMode:themeMode,theme:ThemeData(useMaterial3:true,colorSchemeSeed:seed,scaffoldBackgroundColor:const Color(0xFFF7F5FA),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(width:2,color:seed)))),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:const Color(0xFF9B82DB),inputDecorationTheme:InputDecorationTheme(filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)))),home:Scaffold(appBar:AppBar(title:const Text('App do Poli',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(tooltip:'Alternar tema',onPressed:()=>setState(()=>themeMode=themeMode==ThemeMode.dark?ThemeMode.light:ThemeMode.dark),icon:const Icon(Icons.dark_mode_outlined))]),body:IndexedStack(index:selectedIndex,children:[const AgendaScreen(),const GymScreen(),HomeScreen(key:ValueKey('home-$homeRefresh')),const FoodScreen(),const FinanceScreen()]),bottomNavigationBar:NavigationBar(selectedIndex:selectedIndex,onDestinationSelected:(i)=>setState((){selectedIndex=i;homeRefresh++;}),destinations:const[NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Agenda'),NavigationDestination(icon:Icon(Icons.fitness_center_outlined),selectedIcon:Icon(Icons.fitness_center),label:'Academia'),NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Início'),NavigationDestination(icon:Icon(Icons.restaurant_outlined),selectedIcon:Icon(Icons.restaurant),label:'Alimentação'),NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),selectedIcon:Icon(Icons.account_balance_wallet),label:'Financeiro')])));}
}
