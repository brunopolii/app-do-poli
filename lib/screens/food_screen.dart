import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/date_formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/ai_food_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

enum _FoodPeriodMode{week,month}

class FoodScreen extends StatefulWidget { const FoodScreen({super.key}); @override State<FoodScreen> createState()=>_FoodScreenState(); }
class _FoodScreenState extends State<FoodScreen> {
  final ai=AiFoodService(); List<Meal> meals=[]; List<WeightEntry> weights=[]; Map<String,double>? goals; bool loading=true; _FoodPeriodMode mode=_FoodPeriodMode.week; late DateTime period; DateTime selectedDay=_day(DateTime.now()); String get todayKey=>DateFormat('yyyy-MM-dd').format(DateTime.now()); String get selectedDayKey=>DateFormat('yyyy-MM-dd').format(selectedDay);
  @override void initState(){super.initState();period=_weekStart(DateTime.now());_load();}
  static DateTime _day(DateTime d)=>DateTime(d.year,d.month,d.day);
  static DateTime _weekStart(DateTime d)=>_day(d).subtract(Duration(days:d.weekday%7));
  static DateTime _monthStart(DateTime d)=>DateTime(d.year,d.month,1);
  DateTime get periodStart=>mode==_FoodPeriodMode.week?_weekStart(period):_monthStart(period);
  DateTime get periodEnd=>mode==_FoodPeriodMode.week?periodStart.add(const Duration(days:7)):DateTime(periodStart.year,periodStart.month+1,1);
  DateTime get currentStart{final now=DateTime.now();return mode==_FoodPeriodMode.week?_weekStart(now):_monthStart(now);}
  bool get canGoNext=>periodStart.isBefore(currentStart);
  String get periodLabel{if(mode==_FoodPeriodMode.week){final end=periodEnd.subtract(const Duration(days:1));return '${DateFormat('dd/MM').format(periodStart)} – ${DateFormat('dd/MM/yyyy').format(end)}';}return formatMonthYearPtBr(periodStart);}
  void _setMode(_FoodPeriodMode next){setState((){mode=next;period=next==_FoodPeriodMode.week?_weekStart(DateTime.now()):_monthStart(DateTime.now());});}
  void _move(int delta){setState((){period=mode==_FoodPeriodMode.week?periodStart.add(Duration(days:7*delta)):DateTime(periodStart.year,periodStart.month+delta,1);});}
  Future<void> _load()async{meals=(await StorageService.read('meals')).map(Meal.fromJson).toList();weights=(await StorageService.read('body_weights')).map(WeightEntry.fromJson).toList()..sort((a,b)=>a.date.compareTo(b.date));final p=await SharedPreferences.getInstance();final r=p.getString('nutrition_goals');if(r!=null){final a=r.split('|');if(a.length==4){goals={'calories':double.tryParse(a[0])??0,'protein':double.tryParse(a[1])??0,'carbs':double.tryParse(a[2])??0,'fat':double.tryParse(a[3])??0};}}if(mounted)setState(()=>loading=false);}
  Future<void> _saveMeals()=>StorageService.write('meals',meals.map((e)=>e.toJson()).toList());Future<void> _saveWeights()=>StorageService.write('body_weights',weights.map((e)=>e.toJson()).toList());
  Future<void> _saveWeight(double value,DateTime? date)async{final d=date??selectedDay;weights.add(WeightEntry(date:DateTime(d.year,d.month,d.day,DateTime.now().hour,DateTime.now().minute,DateTime.now().second).toIso8601String(),weight:value));weights.sort((a,b)=>a.date.compareTo(b.date));await _saveWeights();}
  Future<void> _weight()async{final c=TextEditingController();DateTime date=selectedDay;final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('Registrar peso'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Peso',suffixText:'kg')),ListTile(contentPadding:EdgeInsets.zero,title:Text('Data: ${DateFormat('dd/MM/yyyy').format(date)}'),onTap:()async{final r=await showDatePicker(context:d,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(r!=null)setD(()=>date=r);})]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Salvar'))])));final v=double.tryParse(c.text.replaceAll(',','.'));c.dispose();if(ok==true&&v!=null&&v>0){await _saveWeight(v,date);if(mounted)setState((){});}}
  Future<void> _editWeight(WeightEntry e)async{final c=TextEditingController(text:e.weight.toStringAsFixed(1));DateTime date=DateTime.tryParse(e.date)??DateTime.now();final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('Editar peso'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Peso (kg)')),ListTile(contentPadding:EdgeInsets.zero,title:Text('Data: ${DateFormat('dd/MM/yyyy').format(date)}'),onTap:()async{final r=await showDatePicker(context:d,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(r!=null)setD(()=>date=r);})]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Salvar'))])));final v=double.tryParse(c.text.replaceAll(',','.'));c.dispose();if(ok==true&&v!=null&&v>0){e.weight=v;e.date=date.toIso8601String();weights.sort((a,b)=>a.date.compareTo(b.date));await _saveWeights();if(mounted)setState((){});}}
  Future<void> _deleteWeight(WeightEntry e)async{weights.remove(e);await _saveWeights();if(mounted)setState((){});}
  Future<void> _history()async{final rows=[...weights].reversed.toList();await showDialog(context:context,builder:(d)=>AlertDialog(title:const Text('Histórico completo de peso'),content:SizedBox(width:500,height:420,child:rows.isEmpty?const Center(child:Text('Nenhum registro.')):ListView.builder(itemCount:rows.length,itemBuilder:(_,i){final e=rows[i];final dt=DateTime.tryParse(e.date);return ListTile(title:Text('${e.weight.toStringAsFixed(1)} kg'),subtitle:Text(dt==null?e.date:DateFormat('dd/MM/yyyy HH:mm').format(dt)),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit')await _editWeight(e);if(v=='delete')await _deleteWeight(e);},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))]));})),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Fechar'))]));}
  Future<void> _setupGoals()async{final age=TextEditingController(),weight=TextEditingController(),height=TextEditingController();String sex='Masculino',activity='Moderado',objective='Manter peso';final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('Metas nutricionais'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:age,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Idade')),TextField(controller:weight,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Peso (kg)')),TextField(controller:height,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Altura (cm)')),DropdownButtonFormField<String>(initialValue:sex,items:['Masculino','Feminino'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setD(()=>sex=v);}),DropdownButtonFormField<String>(initialValue:activity,items:['Sedentário','Levemente ativo','Moderado','Muito ativo','Extremamente ativo'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setD(()=>activity=v);}),DropdownButtonFormField<String>(initialValue:objective,items:['Perder peso','Manter peso','Ganhar peso'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setD(()=>objective=v);})])),actions:[FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Calcular'))])));final a=double.tryParse(age.text),w=double.tryParse(weight.text.replaceAll(',','.')),h=double.tryParse(height.text.replaceAll(',','.'));if(ok!=true||a==null||w==null||h==null||a<=0||w<=0||h<=0)return;const f=<String,double>{'Sedentário':1.2,'Levemente ativo':1.375,'Moderado':1.55,'Muito ativo':1.725,'Extremamente ativo':1.9};final b=sex=='Masculino'?10*w+6.25*h-5*a+5:10*w+6.25*h-5*a-161;final kcal=b*f[activity]!+(objective=='Perder peso'?-400:objective=='Ganhar peso'?300:0);goals={'calories':kcal,'protein':w*2,'fat':kcal*.27/9,'carbs':(kcal-w*2*4-kcal*.27)/4};final p=await SharedPreferences.getInstance();await p.setString('nutrition_goals','${goals!['calories']}|${goals!['protein']}|${goals!['carbs']}|${goals!['fat']}');if(mounted)setState((){});}
  Future<void> _manual()async{final n=TextEditingController(),q=TextEditingController(),k=TextEditingController(),p=TextEditingController(),c=TextEditingController(),f=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Adicionar alimento'),content:SingleChildScrollView(child:Column(children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Alimento')),TextField(controller:q,decoration:const InputDecoration(labelText:'Quantidade / peso')),TextField(controller:k,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Calorias')),TextField(controller:p,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Proteína (g)')),TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Carboidratos (g)')),TextField(controller:f,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Gorduras (g)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Adicionar'))]));final name=n.text.trim();if(ok==true&&name.isNotEmpty){meals.add(Meal(id:DateTime.now().microsecondsSinceEpoch.toString(),date:selectedDayKey,type:'Refeição',food:q.text.trim().isEmpty?name:'$name (${q.text.trim()})',calories:double.tryParse(k.text.replaceAll(',','.'))??0,protein:double.tryParse(p.text.replaceAll(',','.'))??0,carbs:double.tryParse(c.text.replaceAll(',','.'))??0,fat:double.tryParse(f.text.replaceAll(',','.'))??0));await _saveMeals();if(mounted)setState((){});}for(final x in [n,q,k,p,c,f]){x.dispose();}}
  Future<void> _textAI()async{final c=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Analisar por texto'),content:TextField(controller:c,maxLines:3,decoration:const InputDecoration(hintText:'Ex.: 200g arroz, 150g frango e 2 ovos')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Analisar'))]));final text=c.text.trim();c.dispose();if(ok!=true||text.isEmpty)return;try{await _result(await ai.estimateText(text));}catch(e){_message(e.toString());}}
    Future<void> _editMeal(Meal meal)async{final n=TextEditingController(text:meal.food);final k=TextEditingController(text:meal.calories.toStringAsFixed(1));final p=TextEditingController(text:meal.protein.toStringAsFixed(1));final c=TextEditingController(text:meal.carbs.toStringAsFixed(1));final f=TextEditingController(text:meal.fat.toStringAsFixed(1));DateTime date=DateTime.tryParse(meal.date)??selectedDay;final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:const Text('Editar alimento'),content:SingleChildScrollView(child:Column(children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Alimento / porção')),TextField(controller:k,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Calorias')),TextField(controller:p,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Proteína (g)')),TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Carboidratos (g)')),TextField(controller:f,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Gorduras (g)')),ListTile(contentPadding:EdgeInsets.zero,title:Text('Data: ${DateFormat('dd/MM/yyyy').format(date)}'),onTap:()async{final r=await showDatePicker(context:d,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(r!=null)setD(()=>date=r);})])),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Salvar'))])));if(ok==true&&n.text.trim().isNotEmpty){meal.food=n.text.trim();meal.date=DateFormat('yyyy-MM-dd').format(date);meal.calories=double.tryParse(k.text.replaceAll(',','.'))??meal.calories;meal.protein=double.tryParse(p.text.replaceAll(',','.'))??meal.protein;meal.carbs=double.tryParse(c.text.replaceAll(',','.'))??meal.carbs;meal.fat=double.tryParse(f.text.replaceAll(',','.'))??meal.fat;await _saveMeals();if(mounted)setState((){});}for(final x in [n,k,p,c,f]){x.dispose();}}
  Future<void> _deleteMeal(Meal meal)async{final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Excluir alimento?'),content:Text('Excluir "${meal.food}"?'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Excluir'))]));if(ok==true){meals.removeWhere((m)=>m.id==meal.id);await _saveMeals();if(mounted)setState((){});}}
  Future<void> _pickSelectedDay()async{final r=await showDatePicker(context:context,initialDate:selectedDay,firstDate:DateTime(2020),lastDate:DateTime(2100));if(r!=null&&mounted)setState(()=>selectedDay=r);}
  void _changeSelectedDay(int delta){setState(()=>selectedDay=_day(selectedDay).add(Duration(days:delta)));}
  Future<void> _result(FoodResult r)async{final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Estimativa nutricional'),content:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[for(final i in r.items)ListTile(contentPadding:EdgeInsets.zero,title:Text(i.name),subtitle:Text('${i.grams.toStringAsFixed(0)}g • ${i.calories.toStringAsFixed(0)} kcal • P ${i.protein.toStringAsFixed(1)}g • C ${i.carbs.toStringAsFixed(1)}g • G ${i.fat.toStringAsFixed(1)}g')),const Divider(),Text('${r.calories.toStringAsFixed(0)} kcal • P ${r.protein.toStringAsFixed(1)}g • C ${r.carbs.toStringAsFixed(1)}g • G ${r.fat.toStringAsFixed(1)}g')])),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('NÃO CONTAR')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('CONTAR'))]));if(ok==true){meals.add(Meal(id:DateTime.now().microsecondsSinceEpoch.toString(),date:selectedDayKey,type:'Refeição',food:r.items.map((e)=>e.name).join(', '),calories:r.calories,protein:r.protein,carbs:r.carbs,fat:r.fat,source:'ai'));await _saveMeals();if(mounted)setState((){});}}
  void _message(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  List<WeightEntry?> _chartWeights(){
    final latestByDay=<String,WeightEntry>{};
    for(final e in weights){
      final d=DateTime.tryParse(e.date);
      if(d==null||d.isBefore(periodStart)||!d.isBefore(periodEnd))continue;
      final key=DateFormat('yyyy-MM-dd').format(d);
      final previous=latestByDay[key];
      if(previous==null)latestByDay[key]=e;
      else{
        final previousDate=DateTime.tryParse(previous.date);
        if(previousDate==null||d.isAfter(previousDate))latestByDay[key]=e;
      }
    }
    final out=<WeightEntry?>[];
    final days=mode==_FoodPeriodMode.week?7:periodEnd.difference(periodStart).inDays;
    for(var i=0;i<days;i++){
      final d=periodStart.add(Duration(days:i));
      out.add(latestByDay[DateFormat('yyyy-MM-dd').format(d)]);
    }
    return out;
  }

  double? _previousWeight(){
    WeightEntry? best;
    for(final e in weights){final d=DateTime.tryParse(e.date);if(d==null||!d.isBefore(periodStart))continue;final bd=best==null?null:DateTime.tryParse(best!.date);if(best==null||bd==null||d.isAfter(bd))best=e;}
    return best?.weight;
  }

  double? _nextWeight(){
    WeightEntry? best;
    for(final e in weights){
      final d=DateTime.tryParse(e.date);
      if(d==null||!d.isAfter(periodEnd))continue;
      final bd=best==null?null:DateTime.tryParse(best!.date);
      if(best==null||bd==null||d.isBefore(bd))best=e;
    }
    return best?.weight;
  }

  List<WeightEntry> _periodRecords(){
    final out=weights.where((e){
      final d=DateTime.tryParse(e.date);
      return d!=null&&!d.isBefore(periodStart)&&d.isBefore(periodEnd);
    }).toList();
    out.sort((a,b)=>b.date.compareTo(a.date));
    return out;
  }

  Map<String,double> _totalsForDay(String dayKey){
    final dayMeals=meals.where((m)=>m.date==dayKey);
    return <String,double>{'calories':dayMeals.fold<double>(0,(s,m)=>s+m.calories),'protein':dayMeals.fold<double>(0,(s,m)=>s+m.protein),'carbs':dayMeals.fold<double>(0,(s,m)=>s+m.carbs),'fat':dayMeals.fold<double>(0,(s,m)=>s+m.fat)};
  }
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    final todayMeals=meals.where((m)=>m.date==todayKey);
    final selectedMeals=meals.where((m)=>m.date==selectedDayKey);
    final todayTotals=_totalsForDay(todayKey);
    final todayKcal=todayTotals['calories']!,todayPro=todayTotals['protein']!,todayCarb=todayTotals['carbs']!,todayFat=todayTotals['fat']!;
    final current=weights.isEmpty?null:weights.last;
    final chart=_chartWeights();
    final records=_periodRecords();
    return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Alimentação',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),Text('${todayMeals.length} refeição(ões) hoje')])),IconButton(onPressed:_setupGoals,icon:const Icon(Icons.settings_outlined))]),
      if(goals!=null)AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Metas diárias',style:Theme.of(context).textTheme.titleLarge),_bar('Calorias',todayKcal,goals!['calories']!,'kcal'),_bar('Proteína',todayPro,goals!['protein']!,'g'),_bar('Carboidratos',todayCarb,goals!['carbs']!,'g'),_bar('Gorduras',todayFat,goals!['fat']!,'g')])),
      AppCard(child:Row(children:[const Icon(Icons.monitor_weight_outlined,size:32),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Peso corporal'),Text(current==null?'—':'${current.weight.toStringAsFixed(1)} kg',style:Theme.of(context).textTheme.titleLarge)])),OutlinedButton(onPressed:_weight,child:const Text('Registrar'))])),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Evolução do peso',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        SegmentedButton<_FoodPeriodMode>(
          segments:const[
            ButtonSegment(value:_FoodPeriodMode.week,label:Text('Semanal')),
            ButtonSegment(value:_FoodPeriodMode.month,label:Text('Mensal')),
          ],
          selected:{mode},
          onSelectionChanged:(v){if(v.isNotEmpty)_setMode(v.first);},
        ),
        const SizedBox(height:8),
        Row(children:[
          IconButton(onPressed:()=>_move(-1),icon:const Icon(Icons.chevron_left)),
          Expanded(child:Text(periodLabel,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w600))),
          if(canGoNext)IconButton(onPressed:()=>_move(1),icon:const Icon(Icons.chevron_right))else const SizedBox(width:48),
        ]),
        Text(mode==_FoodPeriodMode.week?'Uma pesagem por dia • última pesagem do dia':'Uma pesagem por dia • última pesagem de cada dia',style:Theme.of(context).textTheme.bodySmall),
        const SizedBox(height:4),
        _WeightChart(data:chart,color:Theme.of(context).colorScheme.primary,startDate:periodStart,previousValue:_previousWeight(),nextValue:_nextWeight()),
        Text('${chart.whereType<WeightEntry>().length} dia(s) com registro • ${weights.length} registro(s) total'),
      ])),
      const SizedBox(height:8),
      Text('Registros do período',style:Theme.of(context).textTheme.titleLarge),
      if(records.isEmpty)const AppCard(child:Text('Nenhum registro de peso neste período.')),
      for(final e in records)ListTile(
        contentPadding:const EdgeInsets.symmetric(horizontal:8),
        title:Text('${e.weight.toStringAsFixed(1)} kg'),
        subtitle:Text(DateTime.tryParse(e.date)==null?e.date:DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(e.date))),
        trailing:PopupMenuButton<String>(
          onSelected:(v)async{if(v=='edit')await _editWeight(e);if(v=='delete')await _deleteWeight(e);},
          itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))],
        ),
      ),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_manual,icon:const Icon(Icons.add),label:const Text('Manual'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:_textAI,icon:const Icon(Icons.auto_awesome),label:const Text('IA texto')))]),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[IconButton(onPressed:()=>_changeSelectedDay(-1),icon:const Icon(Icons.chevron_left)),Expanded(child:Text(DateUtils.dateOnly(selectedDay)==DateUtils.dateOnly(DateTime.now())?'Hoje':DateFormat('dd/MM/yyyy').format(selectedDay),textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge)),IconButton(onPressed:()=>_changeSelectedDay(1),icon:const Icon(Icons.chevron_right)),IconButton(onPressed:_pickSelectedDay,icon:const Icon(Icons.calendar_month))]),if(selectedMeals.isEmpty)const Text('Nenhuma refeição registrada neste dia.'),if(selectedMeals.isNotEmpty&&goals!=null)Padding(padding:const EdgeInsets.only(bottom:12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Metas diárias',style:Theme.of(context).textTheme.titleMedium),_bar('Calorias',_totalsForDay(selectedDayKey)['calories']!,goals!['calories']!,'kcal'),_bar('Proteína',_totalsForDay(selectedDayKey)['protein']!,goals!['protein']!,'g'),_bar('Carboidratos',_totalsForDay(selectedDayKey)['carbs']!,goals!['carbs']!,'g'),_bar('Gorduras',_totalsForDay(selectedDayKey)['fat']!,goals!['fat']!,'g')])),for(final m in selectedMeals)ListTile(contentPadding:EdgeInsets.zero,title:Text(m.food),subtitle:Text('${m.calories.toStringAsFixed(0)} kcal • P ${m.protein.toStringAsFixed(1)}g • C ${m.carbs.toStringAsFixed(1)}g • G ${m.fat.toStringAsFixed(1)}g'),trailing:PopupMenuButton<String>(onSelected:(v)async{if(v=='edit')await _editMeal(m);if(v=='delete')await _deleteMeal(m);},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))]))])),
    ]));
  }
  Widget _bar(String n,double v,double goal,String unit){final ratio=goal<=0?0.0:(v/goal).clamp(0.0,1.0).toDouble();return Padding(padding:const EdgeInsets.only(top:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(n),Text('${v.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} $unit')]),LinearProgressIndicator(value:ratio)]));}
}
class _WeightChart extends StatefulWidget{
  final List<WeightEntry?> data;final Color color;final DateTime startDate;final double? previousValue;final double? nextValue;
  const _WeightChart({required this.data,required this.color,required this.startDate,this.previousValue,this.nextValue});
  @override State<_WeightChart> createState()=>_WeightChartState();
}
class _WeightChartState extends State<_WeightChart>{
  double? selectionX;
  @override Widget build(BuildContext context)=>SizedBox(
    height:250,
    child:GestureDetector(
      behavior:HitTestBehavior.opaque,
      onTapDown:(d)=>setState(()=>selectionX=d.localPosition.dx),
      onHorizontalDragUpdate:(d)=>setState(()=>selectionX=d.localPosition.dx),
      child:CustomPaint(
        painter:_WeightChartPainter(widget.data,widget.color,Theme.of(context).colorScheme.onSurfaceVariant,Directionality.of(context),widget.startDate,widget.previousValue,widget.nextValue,selectionX),
        child:const SizedBox.expand(),
      ),
    ),
  );
}
class _WeightChartPainter extends CustomPainter{
  final List<WeightEntry?> data;final Color color;final Color labelColor;final ui.TextDirection textDirection;final DateTime startDate;final double? previousValue;final double? nextValue;final double? selectionX;
  _WeightChartPainter(this.data,this.color,this.labelColor,this.textDirection,this.startDate,this.previousValue,this.nextValue,this.selectionX);
  @override void paint(Canvas c,Size s){
    if(data.isEmpty)return;const left=42.0,right=12.0,top=26.0,bottom=40.0,edgeInset=10.0;
    final w=math.max(1.0,s.width-left-right),h=math.max(1.0,s.height-top-bottom);
    final pts=<MapEntry<int,WeightEntry>>[];for(var k=0;k<data.length;k++){final p=data[k];if(p!=null)pts.add(MapEntry(k,p));}
    if(pts.isEmpty){_txt(c,'Nada registrado',Offset(s.width/2,s.height/2-10),14,labelColor,TextAlign.center);return;}
    final vals=<double>[];if(previousValue!=null)vals.add(previousValue!);if(nextValue!=null)vals.add(nextValue!);for(final p in data)if(p!=null)vals.add(p.weight);
    final minV=vals.reduce(math.min),maxV=vals.reduce(math.max),raw=math.max(.01,maxV-minV),pad=raw*.12,lo=minV-pad,hi=maxV+pad;
    final innerW=math.max(1.0,w-edgeInset*2).toDouble();
    double x(int i)=>data.length==1?left+w/2:left+edgeInset+innerW*i/(data.length-1);double y(double v)=>top+h-(v-lo)/(hi-lo)*h;
    final grid=Paint()..color=color.withValues(alpha:.14),ticks=Paint()..color=color.withValues(alpha:.10),axis=Paint()..color=color.withValues(alpha:.35);
    for(var j=0;j<=4;j++){final yy=top+h*j/4;c.drawLine(Offset(left,yy),Offset(s.width-right,yy),grid);_txt(c,'${(hi-(hi-lo)*j/4).toStringAsFixed(1)} kg',Offset(2,yy-7),9,labelColor,TextAlign.left);}
    for(var k=0;k<data.length;k++){final xx=x(k);c.drawLine(Offset(xx,top),Offset(xx,s.height-bottom),ticks);final show=data.length<=7||k==0||k==data.length-1||k%5==0;if(show)_txt(c,DateFormat('dd/MM').format(startDate.add(Duration(days:k))),Offset(xx,s.height-bottom+8),9,labelColor,TextAlign.center);}
    final line=Paint()..color=color..strokeWidth=3..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    final segments=<List<Offset>>[];
    if(previousValue!=null)segments.add([Offset(left,y(previousValue!)),Offset(x(pts.first.key),y(pts.first.value.weight))]);
    for(var k=1;k<pts.length;k++)segments.add([Offset(x(pts[k-1].key),y(pts[k-1].value.weight)),Offset(x(pts[k].key),y(pts[k].value.weight))]);
    if(nextValue!=null)segments.add([Offset(x(pts.last.key),y(pts.last.value.weight)),Offset(left+w-edgeInset,y(nextValue!))]);
    final path=Path();
    for(final seg in segments){path.moveTo(seg[0].dx,seg[0].dy);path.lineTo(seg[1].dx,seg[1].dy);}
    if(segments.isNotEmpty)c.drawPath(path,line);

    int? selected;
    if(selectionX!=null&&pts.isNotEmpty){
      selected=0;var best=(x(pts.first.key)-selectionX!).abs();
      for(var i=0;i<pts.length;i++){final d=(x(pts[i].key)-selectionX!).abs();if(d<best){best=d;selected=i;}}
    }
    final values=pts.map((e)=>e.value.weight).toList();
    final minIndex=_indexOfMin(values),maxIndex=_indexOfMax(values);
    final labelIndices=<int>{minIndex,maxIndex};
    if(selected!=null)labelIndices.add(selected!);
    final occupied=<Rect>[];
    for(final i in labelIndices.toList()..sort()){
      final e=pts[i];
      final point=Offset(x(e.key),y(e.value.weight));
      final value=e.value.weight.toStringAsFixed(e.value.weight.truncateToDouble()==e.value.weight?0:1);
      final label=DateFormat('dd/MM/yyyy').format(DateTime.parse(e.value.date))+'\n'+value+' kg';
      _drawLabel(c,s,point,label,segments,occupied,top,bottom);
      c.drawCircle(point,i==selected?9:4,Paint()..color=color);
    }
    for(var i=0;i<pts.length;i++){
      if(labelIndices.contains(i))continue;
      final e=pts[i];
      c.drawCircle(Offset(x(e.key),y(e.value.weight)),i==selected?9:4,Paint()..color=color);
    }

    c.drawLine(Offset(left,top),Offset(left,s.height-bottom),axis);c.drawLine(Offset(left,s.height-bottom),Offset(s.width-right,s.height-bottom),axis);
  }

  int _indexOfMin(List<double> values){var index=0;for(var i=1;i<values.length;i++)if(values[i]<values[index])index=i;return index;}
  int _indexOfMax(List<double> values){var index=0;for(var i=1;i<values.length;i++)if(values[i]>values[index])index=i;return index;}
  bool _segmentsIntersect(Offset a,Offset b,Offset c,Offset d){
    double cross(Offset p,Offset q,Offset r)=>(q.dx-p.dx)*(r.dy-p.dy)-(q.dy-p.dy)*(r.dx-p.dx);
    bool on(Offset p,Offset q,Offset r)=>q.dx>=math.min(p.dx,r.dx)-.01&&q.dx<=math.max(p.dx,r.dx)+.01&&q.dy>=math.min(p.dy,r.dy)-.01&&q.dy<=math.max(p.dy,r.dy)+.01;
    final d1=cross(a,b,c),d2=cross(a,b,d),d3=cross(c,d,a),d4=cross(c,d,b);
    if(d1.abs()<.01&&on(a,c,b))return true;if(d2.abs()<.01&&on(a,d,b))return true;if(d3.abs()<.01&&on(c,a,d))return true;if(d4.abs()<.01&&on(c,b,d))return true;
    return ((d1>0)!=(d2>0))&&((d3>0)!=(d4>0));
  }
  bool _lineHitsRect(List<List<Offset>> segments,Rect rect){
    for(final seg in segments){
      if(rect.contains(seg[0])||rect.contains(seg[1]))return true;
      if(_segmentsIntersect(seg[0],seg[1],rect.topLeft,rect.topRight))return true;
      if(_segmentsIntersect(seg[0],seg[1],rect.topRight,rect.bottomRight))return true;
      if(_segmentsIntersect(seg[0],seg[1],rect.bottomRight,rect.bottomLeft))return true;
      if(_segmentsIntersect(seg[0],seg[1],rect.bottomLeft,rect.topLeft))return true;
    }
    return false;
  }
  void _drawLabel(Canvas c,Size s,Offset point,String label,List<List<Offset>> segments,List<Rect> occupied,double top,double bottom){
    final tp=TextPainter(
      text:TextSpan(text:label,style:TextStyle(fontSize:10,color:labelColor,fontWeight:FontWeight.w600)),
      textDirection:textDirection,
      textAlign:TextAlign.center,
    )..layout(maxWidth:92);

    const pad=3.0;
    final bounds=Rect.fromLTRB(2,2,s.width-2,s.height-bottom-2);

    // Tenta posições cada vez mais afastadas do ponto. Só aceita uma posição
    // quando o texto não cobre a linha do gráfico nem outro rótulo.
    final candidates=<Offset>[];
    for(final distance in <double>[7,14,22,32,44]){
      candidates.addAll([
        Offset(point.dx-tp.width/2,point.dy-tp.height-distance),
        Offset(point.dx-tp.width/2,point.dy+distance),
        Offset(point.dx-tp.width-distance,point.dy-tp.height/2),
        Offset(point.dx+distance,point.dy-tp.height/2),
        Offset(point.dx-tp.width-distance,point.dy-tp.height-distance),
        Offset(point.dx+distance,point.dy-tp.height-distance),
        Offset(point.dx-tp.width-distance,point.dy+distance),
        Offset(point.dx+distance,point.dy+distance),
      ]);
    }

    Offset? chosen;
    Rect? chosenRect;
    for(final pos in candidates){
      final rect=Rect.fromLTWH(
        pos.dx-pad,pos.dy-pad,tp.width+pad*2,tp.height+pad*2,
      );
      if(rect.left<bounds.left||rect.top<bounds.top||
          rect.right>bounds.right||rect.bottom>bounds.bottom)continue;
      if(occupied.any((r)=>r.overlaps(rect)))continue;
      if(_lineHitsRect(segments,rect))continue;
      chosen=pos;
      chosenRect=rect;
      break;
    }

    // Em situações muito apertadas, procura a posição válida mais distante
    // da linha antes de recorrer a qualquer fallback.
    if(chosen==null){
      double bestScore=double.infinity;
      for(final pos in candidates){
        final rect=Rect.fromLTWH(
          pos.dx-pad,pos.dy-pad,tp.width+pad*2,tp.height+pad*2,
        );
        if(rect.left<bounds.left||rect.top<bounds.top||
            rect.right>bounds.right||rect.bottom>bounds.bottom)continue;
        if(occupied.any((r)=>r.overlaps(rect)))continue;
        var score=0.0;
        for(final seg in segments){
          final mid=Offset((seg[0].dx+seg[1].dx)/2,(seg[0].dy+seg[1].dy)/2);
          score+=1/(1+math.sqrt(math.pow(mid.dx-rect.center.dx,2)+math.pow(mid.dy-rect.center.dy,2)));
        }
        if(score<bestScore){bestScore=score;chosen=pos;chosenRect=rect;}
      }
    }

    // Último recurso: posição abaixo do ponto, limitada ao gráfico.
    if(chosen==null){
      final fallbackX=(point.dx-tp.width/2).clamp(
        bounds.left+pad,bounds.right-tp.width-pad,
      ).toDouble();
      final fallbackY=(point.dy+7).clamp(
        bounds.top+pad,bounds.bottom-tp.height-pad,
      ).toDouble();
      chosen=Offset(fallbackX,fallbackY);
      chosenRect=Rect.fromLTWH(
        chosen.dx-pad,chosen.dy-pad,tp.width+pad*2,tp.height+pad*2,
      );
    }

    occupied.add(chosenRect!);
    final edge=Offset(
      point.dx.clamp(chosenRect.left,chosenRect.right).toDouble(),
      point.dy.clamp(chosenRect.top,chosenRect.bottom).toDouble(),
    );
    c.drawLine(
      point,edge,
      Paint()..color=labelColor.withValues(alpha:.35)..strokeWidth=1,
    );
    tp.paint(c,chosen);
  }
  void _txt(Canvas c,String v,Offset p,double size,Color col,TextAlign a){final tp=TextPainter(text:TextSpan(text:v,style:TextStyle(fontSize:size,color:col,fontWeight:FontWeight.w500)),textDirection:textDirection,textAlign:a)..layout(maxWidth:100);tp.paint(c,Offset((a==TextAlign.center?p.dx-tp.width/2:p.dx).clamp(0.0,10000.0).toDouble(),p.dy));}
  @override bool shouldRepaint(covariant _WeightChartPainter o)=>o.data!=data||o.color!=color||o.previousValue!=previousValue||o.nextValue!=nextValue||o.selectionX!=selectionX||o.startDate!=startDate;
}