import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const weekDays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const muscles = ['Peito','Costas','Ombros','Bíceps','Tríceps','Quadríceps','Posterior','Glúteos','Panturrilhas','Abdômen','Outros'];
const defaultExercises = <List<String>>[
  ['Supino reto','Peito'],['Supino inclinado','Peito'],['Crucifixo máquina','Peito'],['Crossover','Peito'],
  ['Puxada aberta','Costas'],['Remada baixa','Costas'],['Remada unilateral','Costas'],['Pulldown','Costas'],
  ['Desenvolvimento','Ombros'],['Elevação lateral','Ombros'],['Elevação frontal','Ombros'],
  ['Rosca direta','Bíceps'],['Rosca alternada','Bíceps'],['Rosca martelo','Bíceps'],
  ['Tríceps corda','Tríceps'],['Tríceps testa','Tríceps'],['Tríceps francês','Tríceps'],
  ['Agachamento','Quadríceps'],['Leg press 45','Quadríceps'],['Cadeira extensora','Quadríceps'],
  ['Mesa flexora','Posterior'],['Stiff','Posterior'],['Flexora sentado','Posterior'],
  ['Hip thrust','Glúteos'],['Abdução de quadril','Glúteos'],['Panturrilha em pé','Panturrilhas'],['Panturrilha sentado','Panturrilhas'],
  ['Abdominal supra','Abdômen'],['Prancha','Abdômen'],['Elevação de pernas','Abdômen'],
];

class GymScreen extends StatefulWidget {
  const GymScreen({super.key});
  @override State<GymScreen> createState() => _GymScreenState();
}
class _GymScreenState extends State<GymScreen> {
  List<WorkoutPlan> plans = [];
  List<List<String>> custom = [];
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    plans=(await StorageService.read('workout_plans')).map(WorkoutPlan.fromJson).toList();
    custom=(await StorageService.read('exercise_library')).map((e)=>[(e['name']??'').toString(),(e['muscle']??'Outros').toString()]).toList();
    if(mounted)setState((){});
  }
  Future<void> _savePlans()=>StorageService.write('workout_plans',plans.map((e)=>e.toJson()).toList());
  List<List<String>> get library { final all=[...defaultExercises,...custom]; final seen=<String>{}; return all.where((e)=>e[0].isNotEmpty&&seen.add(e[0].toLowerCase())).toList(); }

  Future<List<String>?> _newExercise() async {
    final controller=TextEditingController(); String group='Outros';
    final result=await showDialog<List<String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD){
      return AlertDialog(title:const Text('Novo exercício'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:controller,decoration:const InputDecoration(labelText:'Nome')),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:group,items:muscles.map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:(v){if(v!=null)setD(()=>group=v);},decoration:const InputDecoration(labelText:'Grupo muscular'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('CANCELAR')),FilledButton(onPressed:(){final n=controller.text.trim();if(n.isNotEmpty)Navigator.pop(ctx,[n,group]);},child:const Text('SALVAR'))]);
    }));
    controller.dispose();
    if(result==null)return null;
    if(!library.any((e)=>e[0].toLowerCase()==result[0].toLowerCase())){
      custom.add(result);
      await StorageService.write('exercise_library',custom.map((e)=>{'name':e[0],'muscle':e[1]}).toList());
      if(mounted)setState((){});
    }
    return result;
  }

  Future<void> _editPlan([WorkoutPlan? old]) async {
    final name=TextEditingController(text:old?.name??'');
    final selected=<int>{...(old?.weekdays??const <int>{})};
    final dayExercises=<String,List<Exercise>>{};
    if(old!=null){old.dayExercises.forEach((k,v){dayExercises[k]=v.map((e)=>Exercise(id:e.id,name:e.name,muscle:e.muscle,sets:e.sets,reps:e.reps)).toList();});}
    final result=await Navigator.push<WorkoutPlanDraft>(context,MaterialPageRoute(builder:(_)=>PlanBuilder(name:name.text,initialDays:selected,initialExercises:dayExercises,library:library,newExercise:_newExercise)));
    name.dispose();
    if(result==null)return;
    final plan=old??WorkoutPlan(id:DateTime.now().microsecondsSinceEpoch.toString(),name:result.name,weekdays:[],dayExercises:{});
    plan.name=result.name;plan.weekdays=result.weekdays.toList()..sort();plan.dayExercises=result.dayExercises;
    if(old==null)plans.add(plan);
    await _savePlans();
    if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Treino salvo com sucesso.')));}
  }
  Future<void> _deletePlan(WorkoutPlan p) async { final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Excluir treino?'),content:Text('Excluir ${p.name}?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('CANCELAR')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('EXCLUIR'))]));if(ok!=true)return;plans.removeWhere((x)=>x.id==p.id);await _savePlans();if(mounted)setState((){}); }
  Future<void> _start(WorkoutPlan p,int day) async { final ex=p.exercisesFor(day).map((e)=>Exercise(id:e.id,name:e.name,muscle:e.muscle,sets:e.sets,reps:e.reps)).toList();if(ex.isEmpty)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>WorkoutExecution(name:p.name,weekday:day,exercises:ex))); }

  @override Widget build(BuildContext context){
    final today=DateTime.now().weekday;final todayPlans=plans.where((p)=>p.weekdays.contains(today)&&p.exercisesFor(today).isNotEmpty).toList();
    return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Academia',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),Text('${plans.length} treino(s) configurado(s)')])),FilledButton.icon(onPressed:()=>_editPlan(),icon:const Icon(Icons.add),label:const Text('Criar treino'))]),
      const SizedBox(height:16),
      if(todayPlans.isNotEmpty)AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Treino de hoje',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),...todayPlans.map((p)=>ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(child:Icon(Icons.fitness_center)),title:Text(p.name),subtitle:Text('${p.exercisesFor(today).length} exercícios • ${weekDays[today-1]}'),trailing:FilledButton(onPressed:()=>_start(p,today),child:const Text('Iniciar')))])),
      if(plans.isEmpty)const AppCard(child:Text('Nenhum treino criado.')),
      ...plans.map((p)=>AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const CircleAvatar(child:Icon(Icons.fitness_center)),const SizedBox(width:10),Expanded(child:Text(p.name,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),PopupMenuButton<String>(onSelected:(v){if(v=='edit')_editPlan(p);if(v=='delete')_deletePlan(p);},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))])]),...p.weekdays.map((d)=>ListTile(contentPadding:EdgeInsets.zero,dense:true,title:Text(weekDays[d-1]),subtitle:Text(p.exercisesFor(d).map((e)=>'${e.name} (${e.sets}×${e.reps})').join(', ')),trailing:IconButton(onPressed:()=>_start(p,d),icon:const Icon(Icons.play_arrow))))]))),
      const _History(),
    ]));
  }
}

class WorkoutPlanDraft{final String name;final Set<int> weekdays;final Map<String,List<Exercise>> dayExercises;WorkoutPlanDraft({required this.name,required this.weekdays,required this.dayExercises});}

class PlanBuilder extends StatefulWidget{
  final String name;final Set<int> initialDays;final Map<String,List<Exercise>> initialExercises;final List<List<String>> library;final Future<List<String>?> Function() newExercise;
  const PlanBuilder({super.key,required this.name,required this.initialDays,required this.initialExercises,required this.library,required this.newExercise});
  @override State<PlanBuilder> createState()=>_PlanBuilderState();
}
class _PlanBuilderState extends State<PlanBuilder>{late TextEditingController name;late Set<int> days;late Map<String,List<Exercise>> exercises;
  @override void initState(){super.initState();name=TextEditingController(text:widget.name);days={...widget.initialDays};exercises={};widget.initialExercises.forEach((k,v){exercises[k]=v.map((e)=>e.copy()).toList();});}
  @override void dispose(){name.dispose();super.dispose();}
  Future<void> _day(int day)async{final result=await Navigator.push<List<Exercise>>(context,MaterialPageRoute(builder:(_)=>DayEditor(day:day,initial:(exercises['$day']??[]).map((e)=>e.copy()).toList(),library:widget.library,newExercise:widget.newExercise)));if(result!=null&&mounted)setState((){days.add(day);exercises['$day']=result;});}
  void _save(){final valid=days.where((d)=>(exercises['$d']??[]).isNotEmpty).toSet();if(name.text.trim().isEmpty||valid.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Informe o nome e configure pelo menos um dia.')));return;}Navigator.pop(context,WorkoutPlanDraft(name:name.text.trim(),weekdays:valid,dayExercises:exercises));}
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:const Text('Configurar treino')),body:ListView(padding:const EdgeInsets.all(16),children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nome do treino')),const SizedBox(height:16),...List.generate(7,(i){final d=i+1;return Card(child:ListTile(title:Text(weekDays[i]),subtitle:Text('${exercises['$d']?.length??0} exercício(s)'),trailing:const Icon(Icons.chevron_right),onTap:()=>_day(d)));}),FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save),label:const Text('SALVAR TREINO'))]));}
}

class DayEditor extends StatefulWidget{final int day;final List<Exercise> initial;final List<List<String>> library;final Future<List<String>?> Function() newExercise;const DayEditor({super.key,required this.day,required this.initial,required this.library,required this.newExercise});@override State<DayEditor> createState()=>_DayEditorState();}
class _DayEditorState extends State<DayEditor>{late List<Exercise> list;@override void initState(){super.initState();list=widget.initial;}
  Future<void> _add()async{final e=await showDialog<Exercise>(context:context,builder:(_)=>ExercisePicker(library:widget.library,newExercise:widget.newExercise));if(e!=null&&mounted)setState(()=>list.add(e));}
  Future<void> _edit(int i)async{final e=await showDialog<Exercise>(context:context,builder:(_)=>ExerciseSettings(initial:list[i]));if(e!=null&&mounted)setState(()=>list[i]=e);}
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:Text(weekDays[widget.day-1]),actions:[TextButton(onPressed:()=>Navigator.pop(context,list),child:const Text('SALVAR'))]),body:ListView(padding:const EdgeInsets.all(16),children:[...List.generate(list.length,(i)=>Card(child:ListTile(title:Text(list[i].name),subtitle:Text('${list[i].muscle} • ${list[i].sets} séries × ${list[i].reps} reps'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>_edit(i),icon:const Icon(Icons.tune)),IconButton(onPressed:()=>setState(()=>list.removeAt(i)),icon:const Icon(Icons.delete_outline))]))),OutlinedButton.icon(onPressed:_add,icon:const Icon(Icons.add),label:const Text('ADICIONAR EXERCÍCIO'))]));}
}

class ExercisePicker extends StatefulWidget{final List<List<String>> library;final Future<List<String>?> Function() newExercise;const ExercisePicker({super.key,required this.library,required this.newExercise});@override State<ExercisePicker> createState()=>_ExercisePickerState();}
class _ExercisePickerState extends State<ExercisePicker>{String query='';String group='Todos';String? selected;
  @override Widget build(BuildContext context){final filtered=widget.library.where((e)=>(group=='Todos'||e[1]==group)&&e[0].toLowerCase().contains(query.toLowerCase())).toList();return AlertDialog(title:const Text('Escolher exercício'),content:SizedBox(width:500,height:450,child:Column(children:[TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(labelText:'Buscar')),DropdownButtonFormField<String>(initialValue:group,items:['Todos',...muscles].map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:(v){if(v!=null)setState(()=>group=v);}),Expanded(child:ListView(children:filtered.map((e)=>ListTile(selected:selected==e[0],title:Text(e[0]),subtitle:Text(e[1]),onTap:()=>setState(()=>selected=e[0]))).toList()))])),actions:[TextButton(onPressed:()async{final e=await widget.newExercise();if(e!=null&&mounted)setState(()=>selected=e[0]);},child:const Text('NOVO EXERCÍCIO')),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CANCELAR')),FilledButton(onPressed:(){if(selected==null)return;final e=widget.library.firstWhere((x)=>x[0]==selected);Navigator.pop(context,Exercise(id:DateTime.now().microsecondsSinceEpoch.toString(),name:e[0],muscle:e[1],sets:3,reps:10));},child:const Text('ADICIONAR'))]);}
}

class ExerciseSettings extends StatefulWidget{final Exercise initial;const ExerciseSettings({super.key,required this.initial});@override State<ExerciseSettings> createState()=>_ExerciseSettingsState();}
class _ExerciseSettingsState extends State<ExerciseSettings>{late int sets;late int reps;@override void initState(){super.initState();sets=widget.initial.sets;reps=widget.initial.reps;}@override Widget build(BuildContext context){return AlertDialog(title:Text(widget.initial.name),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('Séries: $sets'),Slider(value:sets.toDouble(),min:1,max:12,divisions:11,onChanged:(v)=>setState(()=>sets=v.round())),Text('Repetições: $reps'),Slider(value:reps.toDouble(),min:1,max:30,divisions:29,onChanged:(v)=>setState(()=>reps=v.round())),const Text('A carga é informada somente na execução.',textAlign:TextAlign.center)]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CANCELAR')),FilledButton(onPressed:()=>Navigator.pop(context,Exercise(id:widget.initial.id,name:widget.initial.name,muscle:widget.initial.muscle,sets:sets,reps:reps)),child:const Text('SALVAR'))]);}}

class WorkoutExecution extends StatefulWidget{final String name;final int weekday;final List<Exercise> exercises;const WorkoutExecution({super.key,required this.name,required this.weekday,required this.exercises});@override State<WorkoutExecution> createState()=>_WorkoutExecutionState();}
class _WorkoutExecutionState extends State<WorkoutExecution>{late List<List<TextEditingController>> controllers;late List<List<bool>> done;@override void initState(){super.initState();controllers=widget.exercises.map((e)=>List.generate(e.sets,(_)=>TextEditingController())).toList();done=widget.exercises.map((e)=>List<bool>.filled(e.sets,false)).toList();}@override void dispose(){for(final row in controllers){for(final c in row)c.dispose();}super.dispose();}
  double? _kg(int i,int s)=>double.tryParse(controllers[i][s].text.replaceAll(',','.').trim());
  Future<void> _finish()async{for(var i=0;i<widget.exercises.length;i++){for(var s=0;s<widget.exercises[i].sets;s++){final kg=_kg(i,s);if(!done[i][s]||kg==null||kg<0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Informe a carga e conclua todas as séries.')));return;}}}final completed=<Exercise>[];for(var i=0;i<widget.exercises.length;i++){final e=widget.exercises[i].copy();e.weights=List.generate(e.sets,(s)=>_kg(i,s)!);e.done=[...done[i]];completed.add(e);}final history=await StorageService.read('workout_history');history.add(Workout(id:DateTime.now().microsecondsSinceEpoch.toString(),name:widget.name,date:DateTime.now().toIso8601String(),weekday:widget.weekday,exercises:completed).toJson());await StorageService.write('workout_history',history);if(mounted)Navigator.pop(context);}
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:Text(widget.name)),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('Execução do treino',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:8),...List.generate(widget.exercises.length,(i)=>AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.exercises[i].name,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),Text(widget.exercises[i].muscle),...List.generate(widget.exercises[i].sets,(s)=>Row(children:[SizedBox(width:65,child:Text('Série ${s+1}')),SizedBox(width:90,child:TextField(controller:controllers[i][s],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(hintText:'kg'))),Expanded(child:Text('${widget.exercises[i].reps} reps')),Checkbox(value:done[i][s],onChanged:(v)=>setState(()=>done[i][s]=v==true))]))]))),FilledButton(onPressed:_finish,child:const Text('FINALIZAR TREINO'))]);}
}

class _History extends StatefulWidget{const _History();@override State<_History> createState()=>_HistoryState();}
class _HistoryState extends State<_History>{List<Workout> history=[];String? exercise;@override void initState(){super.initState();_load();}Future<void> _load()async{history=(await StorageService.read('workout_history')).map(Workout.fromJson).toList();if(mounted)setState((){});}@override Widget build(BuildContext context){if(history.isEmpty)return const SizedBox.shrink();final names=history.expand((w)=>w.exercises.map((e)=>e.name)).toSet().toList()..sort();exercise??=(names.isEmpty?null:names.first);return AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Histórico e evolução',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),if(exercise!=null)DropdownButtonFormField<String>(initialValue:exercise,items:names.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>exercise=v),decoration:const InputDecoration(labelText:'Exercício')),...history.where((w)=>w.exercises.any((e)=>e.name==exercise)).take(10).map((w){final e=w.exercises.firstWhere((e)=>e.name==exercise);final max=e.weights.fold<double>(0,(a,b)=>b>a?b:a);return ListTile(contentPadding:EdgeInsets.zero,title:Text('${max.toStringAsFixed(1)} kg'),subtitle:Text(w.date.substring(0,10)));})]));}}
