import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  List<AgendaEvent> events=[]; List<Meal> meals=[]; List<MoneyTransaction> money=[]; List<WorkoutPlan> plans=[]; bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    events=(await StorageService.read('agenda')).map(AgendaEvent.fromJson).toList();
    meals=(await StorageService.read('meals')).map(Meal.fromJson).toList();
    money=(await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList();
    plans=(await StorageService.read('workout_plans')).map(WorkoutPlan.fromJson).toList();
    if(mounted)setState(()=>loading=false);
  }
  double _food(Iterable<Meal> xs,int type){double total=0;for(final x in xs){if(type==0)total+=x.calories;if(type==1)total+=x.protein;if(type==2)total+=x.carbs;if(type==3)total+=x.fat;}return total;}
  double _cash(Iterable<MoneyTransaction> xs,bool income,{bool paid=false}){double total=0;for(final x in xs){if(x.income==income&&(!paid||x.isPaid)&&!x.isCancelled)total+=x.amount;}return total;}
  double _committed(DateTime d)=>money.where((x)=>x.date.startsWith(DateFormat('yyyy-MM').format(d))&&!x.income&&!x.isPaid&&!x.isCancelled).fold(0.0,(s,x)=>s+x.amount);
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    final now=DateTime.now(); final today=DateFormat('yyyy-MM-dd').format(now); final todayEvents=events.where((e)=>e.date==today).toList()..sort((a,b)=>a.start.compareTo(b.start)); final todayMeals=meals.where((e)=>e.date==today); final todayPlans=plans.where((p)=>p.weekdays.contains(now.weekday)&&p.exercisesFor(now.weekday).isNotEmpty).toList(); final currentMonth=money.where((x)=>x.date.startsWith(DateFormat('yyyy-MM').format(now))); final income=_cash(currentMonth,true,paid:true); final expense=_cash(currentMonth,false,paid:true); final balance=_cash(money,true,paid:true)-_cash(money,false,paid:true); final next=DateTime(now.year,now.month+1); final nextIncome=_cash(money.where((x)=>x.date.startsWith(DateFormat('yyyy-MM').format(next))),true); final nextExpense=_cash(money.where((x)=>x.date.startsWith(DateFormat('yyyy-MM').format(next))),false);
    Widget appointments;
    if(todayEvents.isEmpty){appointments=const Text('Nada agendado hoje.');}else{appointments=Column(children:todayEvents.take(4).map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(child:Icon(Icons.event)),title:Text(e.title),subtitle:Text('${e.start} • ${e.end}'))).toList());}
    return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      Text('Olá! 👋',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
      Text(DateFormat("EEEE, dd 'de' MMMM",'pt_BR').format(now)),const SizedBox(height:16),
      _card('Resumo de hoje',Row(children:[_counter(Icons.event_outlined,'Compromissos',todayEvents.length),_counter(Icons.fitness_center,'Treinos',todayPlans.length),_counter(Icons.restaurant_outlined,'Refeições',todayMeals.length)])),
      _card('Próximos compromissos',appointments),
      _card('Alimentação de hoje',Row(children:[_stat(_food(todayMeals,0).toStringAsFixed(0),'kcal'),_stat('${_food(todayMeals,1).toStringAsFixed(0)}g','proteína'),_stat('${_food(todayMeals,2).toStringAsFixed(0)}g','carboidratos'),_stat('${_food(todayMeals,3).toStringAsFixed(0)}g','gorduras')])),
      _card('Financeiro do mês',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[_stat('R\$ ${income.toStringAsFixed(0)}','entradas'),_stat('R\$ ${expense.toStringAsFixed(0)}','despesas'),_stat('R\$ ${(income-expense).toStringAsFixed(0)}','resultado')]),const SizedBox(height:8),Text('Saldo atual: R\$ ${balance.toStringAsFixed(2)}'),Text('Comprometido no mês: R\$ ${_committed(now).toStringAsFixed(2)}'),Text('Próximo mês projetado: R\$ ${(nextIncome-nextExpense).toStringAsFixed(2)}')])),
    ]));
  }
  Widget _card(String title,Widget child)=>AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:10),child]));
  Widget _counter(IconData icon,String label,int value)=>Expanded(child:Column(children:[Icon(icon),const SizedBox(height:4),Text('$value',style:const TextStyle(fontWeight:FontWeight.bold)),Text(label,style:Theme.of(context).textTheme.bodySmall)]));
  Widget _stat(String value,String label)=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),Text(label,style:Theme.of(context).textTheme.bodySmall)]));
}
