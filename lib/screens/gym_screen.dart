import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/date_formatters.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';
const weekDays=['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'];
const muscleGroups=['Peito','Costas','Ombros','Bíceps','Tríceps','Quadríceps','Posterior','Glúteos','Panturrilhas','Abdômen','Outros'];
const defaultExercises=<Map<String,String>>[
{'name':'Supino reto','muscle':'Peito','imagePath':'assets/exercises/supino-reto.svg'},
{'name':'Supino inclinado','muscle':'Peito','imagePath':'assets/exercises/supino-inclinado.svg'},
{'name':'Supino com halteres','muscle':'Peito','imagePath':'assets/exercises/supino-com-halteres.svg'},
{'name':'Supino declinado','muscle':'Peito','imagePath':'assets/exercises/supino-declinado.svg'},
{'name':'Supino fechado','muscle':'Peito','imagePath':'assets/exercises/supino-fechado.svg'},
{'name':'Crucifixo máquina','muscle':'Peito','imagePath':'assets/exercises/crucifixo-maquina.svg'},
{'name':'Crucifixo com halteres','muscle':'Peito','imagePath':'assets/exercises/crucifixo-halteres.svg'},
{'name':'Crossover','muscle':'Peito','imagePath':'assets/exercises/crossover.svg'},
{'name':'Paralelas para peito','muscle':'Peito','imagePath':'assets/exercises/paralelas-peito.svg'},
{'name':'Flexão de braço','muscle':'Peito','imagePath':'assets/exercises/flexao.svg'},
{'name':'Puxada aberta','muscle':'Costas','imagePath':'assets/exercises/puxada-aberta.svg'},
{'name':'Puxada fechada','muscle':'Costas','imagePath':'assets/exercises/puxada-fechada.svg'},
{'name':'Pulldown','muscle':'Costas','imagePath':'assets/exercises/pulldown.svg'},
{'name':'Remada baixa','muscle':'Costas','imagePath':'assets/exercises/remada-baixa.svg'},
{'name':'Remada unilateral','muscle':'Costas','imagePath':'assets/exercises/remada-unilateral.svg'},
{'name':'Remada curvada','muscle':'Costas','imagePath':'assets/exercises/remada-curvada.svg'},
{'name':'Remada apoiada','muscle':'Costas','imagePath':'assets/exercises/remada-apoiada.svg'},
{'name':'Barra fixa','muscle':'Costas','imagePath':'assets/exercises/barra-fixa.svg'},
{'name':'Remada Meadows','muscle':'Costas','imagePath':'assets/exercises/remada-meadows.svg'},
{'name':'Face pull','muscle':'Costas','imagePath':'assets/exercises/face-pull.svg'},
{'name':'Desenvolvimento','muscle':'Ombros','imagePath':'assets/exercises/desenvolvimento.svg'},
{'name':'Desenvolvimento Arnold','muscle':'Ombros','imagePath':'assets/exercises/desenvolvimento-arnold.svg'},
{'name':'Elevação lateral','muscle':'Ombros','imagePath':'assets/exercises/elevacao-lateral.svg'},
{'name':'Elevação lateral no cabo','muscle':'Ombros','imagePath':'assets/exercises/elevacao-lateral-cabo.svg'},
{'name':'Elevação frontal','muscle':'Ombros','imagePath':'assets/exercises/elevacao-frontal.svg'},
{'name':'Crucifixo inverso','muscle':'Ombros','imagePath':'assets/exercises/crucifixo-inverso.svg'},
{'name':'Encolhimento','muscle':'Ombros','imagePath':'assets/exercises/encolhimento.svg'},
{'name':'Rosca direta','muscle':'Bíceps','imagePath':'assets/exercises/rosca-direta.svg'},
{'name':'Rosca martelo','muscle':'Bíceps','imagePath':'assets/exercises/rosca-martelo.svg'},
{'name':'Rosca Scott','muscle':'Bíceps','imagePath':'assets/exercises/rosca-scott.svg'},
{'name':'Rosca concentrada','muscle':'Bíceps','imagePath':'assets/exercises/rosca-concentrada.svg'},
{'name':'Rosca EZ','muscle':'Bíceps','imagePath':'assets/exercises/rosca-ez.svg'},
{'name':'Tríceps corda','muscle':'Tríceps','imagePath':'assets/exercises/triceps-corda.svg'},
{'name':'Tríceps testa','muscle':'Tríceps','imagePath':'assets/exercises/triceps-testa.svg'},
{'name':'Tríceps francês','muscle':'Tríceps','imagePath':'assets/exercises/triceps-frances.svg'},
{'name':'Mergulho no banco','muscle':'Tríceps','imagePath':'assets/exercises/mergulho-banco.svg'},
{'name':'Agachamento','muscle':'Quadríceps','imagePath':'assets/exercises/agachamento.svg'},
{'name':'Agachamento frontal','muscle':'Quadríceps','imagePath':'assets/exercises/agachamento-frontal.svg'},
{'name':'Agachamento búlgaro','muscle':'Quadríceps','imagePath':'assets/exercises/agachamento-bulgaro.svg'},
{'name':'Goblet squat','muscle':'Quadríceps','imagePath':'assets/exercises/goblet-squat.svg'},
{'name':'Hack squat','muscle':'Quadríceps','imagePath':'assets/exercises/hack-squat.svg'},
{'name':'Leg press 45','muscle':'Quadríceps','imagePath':'assets/exercises/leg-press-45.svg'},
{'name':'Cadeira extensora','muscle':'Quadríceps','imagePath':'assets/exercises/cadeira-extensora.svg'},
{'name':'Afundo','muscle':'Quadríceps','imagePath':'assets/exercises/afundo.svg'},
{'name':'Passada','muscle':'Quadríceps','imagePath':'assets/exercises/passada.svg'},
{'name':'Mesa flexora','muscle':'Posterior','imagePath':'assets/exercises/mesa-flexora.svg'},
{'name':'Stiff','muscle':'Posterior','imagePath':'assets/exercises/stiff.svg'},
{'name':'Levantamento terra','muscle':'Posterior','imagePath':'assets/exercises/levantamento-terra.svg'},
{'name':'Nordic curl','muscle':'Posterior','imagePath':'assets/exercises/nordic-curl.svg'},
{'name':'Hip thrust','muscle':'Glúteos','imagePath':'assets/exercises/hip-thrust.svg'},
{'name':'Glute bridge','muscle':'Glúteos','imagePath':'assets/exercises/glute-bridge.svg'},
{'name':'Glúteo no cabo','muscle':'Glúteos','imagePath':'assets/exercises/gluteo-cabo.svg'},
{'name':'Panturrilha em pé','muscle':'Panturrilhas','imagePath':'assets/exercises/panturrilha-em-pe.svg'},
{'name':'Panturrilha sentada','muscle':'Panturrilhas','imagePath':'assets/exercises/panturrilha-sentada.svg'},
{'name':'Panturrilha no leg press','muscle':'Panturrilhas','imagePath':'assets/exercises/panturrilha-leg-press.svg'},
{'name':'Abdominal supra','muscle':'Abdômen','imagePath':'assets/exercises/abdominal-supra.svg'},
{'name':'Abdominal infra','muscle':'Abdômen','imagePath':'assets/exercises/abdominal-infra.svg'},
{'name':'Elevação de joelhos','muscle':'Abdômen','imagePath':'assets/exercises/elevacao-joelhos.svg'},
{'name':'Elevação de pernas','muscle':'Abdômen','imagePath':'assets/exercises/elevacao-pernas.svg'},
{'name':'Prancha','muscle':'Abdômen','imagePath':'assets/exercises/prancha.svg'},
];
typedef ExerciseInfo=Map<String,String>;
String defaultExerciseImage(String name){
  for(final e in defaultExercises){
    if(e['name']==name)return e['imagePath']!;
  }
  return '';
}

class GymScreen extends StatefulWidget{const GymScreen({super.key});@override State<GymScreen> createState()=>GymScreenState();}
class GymScreenState extends State<GymScreen>{List<WorkoutPlan> plans=[];List<ExerciseInfo> custom=[];int _historyRefresh=0;@override void initState(){super.initState();load();}Future<void> load()async{plans=(await StorageService.read('workout_plans')).map(WorkoutPlan.fromJson).toList();for(final p in plans){for(final list in p.dayExercises.values){for(final e in list){if(e.imagePath.isEmpty)e.imagePath=defaultExerciseImage(e.name);}}}custom=(await StorageService.read('exercise_library')).map((e)=><String,String>{'name':'${e['name']??''}','muscle':'${e['muscle']??'Outros'}','equipment':'${e['equipment']??''}','description':'${e['description']??''}','imagePath':'${e['imagePath']??''}'}).where((e)=>e['name']!.isNotEmpty).toList();if(mounted)setState(()=>_historyRefresh++);}Future<void> refresh()async{await load();}List<ExerciseInfo> get library{final all=<ExerciseInfo>[...defaultExercises.map((e)=><String,String>{'name':e['name']!,'muscle':e['muscle']!,'equipment':'','description':'','imagePath':e['imagePath']!}),...custom];final seen=<String>{};final unique=all.where((e)=>seen.add(e['name']!.toLowerCase())).toList();unique.sort((a,b){final am=muscleGroups.indexOf(a['muscle']!);final bm=muscleGroups.indexOf(b['muscle']!);final group=(am<0?999:am).compareTo(bm<0?999:bm);return group!=0?group:a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase());});return unique;}Future<ExerciseInfo?> newExercise()async{final result=await showDialog<ExerciseInfo>(context:context,builder:(_)=>const NewExerciseDialog());if(result==null)return null;if(!library.any((e)=>e['name']!.toLowerCase()==result['name']!.toLowerCase())){custom.add(result);await StorageService.write('exercise_library',custom);}return result;}Future<void> savePlans()=>StorageService.write('workout_plans',plans.map((e)=>e.toJson()).toList());Future<void> editPlan([WorkoutPlan? old])async{final draft=await Navigator.push<WorkoutPlanDraft>(context,MaterialPageRoute(builder:(_)=>PlanEditor(old:old,library:library,newExercise:newExercise)));if(draft==null)return;final p=old??WorkoutPlan(id:DateTime.now().microsecondsSinceEpoch.toString(),name:draft.name,weekdays:[],dayExercises:{});p.name=draft.name;p.weekdays=draft.weekdays.toList()..sort();p.dayExercises=draft.dayExercises;if(old==null)plans.add(p);await savePlans();if(mounted)setState((){});}Future<void> deletePlan(WorkoutPlan p)async{final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Excluir treino?'),content:Text('Excluir ${p.name}? O histórico será preservado.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Excluir'))]));if(ok==true){plans.removeWhere((x)=>x.id==p.id);await savePlans();if(mounted)setState((){});}}Future<void> startWorkout(WorkoutPlan p,int day)async{final ex=p.exercisesFor(day).map((e)=>Exercise(id:e.id,name:e.name,muscle:e.muscle,sets:e.sets,reps:e.reps,imagePath:e.imagePath)).toList();if(ex.isEmpty)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>WorkoutExecution(name:p.name,weekday:day,exercises:ex)));if(mounted)await load();}@override Widget build(BuildContext context){final today=DateTime.now().weekday;return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Academia',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),Text('${plans.length} treino(s) configurado(s)')])),FilledButton.icon(onPressed:()=>editPlan(),icon:const Icon(Icons.add),label:const Text('Criar treino'))]),const SizedBox(height:12),if(plans.isEmpty)const AppCard(child:Text('Nenhum treino criado.')),for(final p in plans)AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.fitness_center),const SizedBox(width:8),Expanded(child:Text(p.name,style:Theme.of(context).textTheme.titleLarge)),PopupMenuButton<String>(onSelected:(v){if(v=='edit')editPlan(p);if(v=='delete')deletePlan(p);},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))])]),for(final d in p.weekdays)ListTile(contentPadding:EdgeInsets.zero,title:Text(weekDays[d-1]),subtitle:Text(p.exercisesFor(d).map((e)=>'${e.name} (${e.sets}×${e.reps})').join(', ')),trailing:IconButton(onPressed:()=>startWorkout(p,d),icon:const Icon(Icons.play_arrow)))])),if(plans.any((p)=>p.weekdays.contains(today)))const SizedBox(height:4),HistorySection(key:ValueKey(_historyRefresh))]));}}
class NewExerciseDialog extends StatefulWidget{const NewExerciseDialog({super.key});@override State<NewExerciseDialog> createState()=>_NewExerciseDialogState();}
class _NewExerciseDialogState extends State<NewExerciseDialog>{final name=TextEditingController(),equipment=TextEditingController(),description=TextEditingController();String muscle='Outros',imagePath='';@override void dispose(){name.dispose();equipment.dispose();description.dispose();super.dispose();}Future<void> pickImage()async{final picked=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:85);if(picked==null)return;final dir=await getApplicationDocumentsDirectory();final folder=Directory('${dir.path}/exercises');await folder.create(recursive:true);final ext=picked.path.contains('.')?picked.path.substring(picked.path.lastIndexOf('.')):'.jpg';final file=File('${folder.path}/${DateTime.now().microsecondsSinceEpoch}$ext');await file.writeAsBytes(await picked.readAsBytes(),flush:true);if(mounted){await precacheImage(FileImage(file),context);setState(()=>imagePath=file.path);}}@override Widget build(BuildContext context)=>AlertDialog(title:const Text('Novo exercício'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nome *')),DropdownButtonFormField<String>(initialValue:muscle,items:muscleGroups.map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:(v){if(v!=null)setState(()=>muscle=v);},decoration:const InputDecoration(labelText:'Grupo muscular')),TextField(controller:equipment,decoration:const InputDecoration(labelText:'Equipamento (opcional)')),TextField(controller:description,maxLines:2,decoration:const InputDecoration(labelText:'Descrição (opcional)')),OutlinedButton.icon(onPressed:pickImage,icon:const Icon(Icons.image_outlined),label:Text(imagePath.isEmpty?'Adicionar imagem':'Imagem selecionada'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),FilledButton(onPressed:(){final n=name.text.trim();if(n.isEmpty)return;Navigator.pop(context,<String,String>{'name':n,'muscle':muscle,'equipment':equipment.text.trim(),'description':description.text.trim(),'imagePath':imagePath});},child:const Text('Salvar'))]);}
class WorkoutPlanDraft{final String name;final Set<int> weekdays;final Map<String,List<Exercise>> dayExercises;WorkoutPlanDraft({required this.name,required this.weekdays,required this.dayExercises});}
class PlanEditor extends StatefulWidget{final WorkoutPlan? old;final List<ExerciseInfo> library;final Future<ExerciseInfo?> Function() newExercise;const PlanEditor({super.key,required this.old,required this.library,required this.newExercise});@override State<PlanEditor> createState()=>_PlanEditorState();}
class _PlanEditorState extends State<PlanEditor>{late TextEditingController name;final days=<int>{};final ex=<String,List<Exercise>>{};@override void initState(){super.initState();name=TextEditingController(text:widget.old?.name??'');if(widget.old!=null){days.addAll(widget.old!.weekdays);widget.old!.dayExercises.forEach((k,v)=>ex[k]=v.map((e)=>e.copy()).toList());}}@override void dispose(){name.dispose();super.dispose();}Future<void> day(int d)async{final r=await Navigator.push<List<Exercise>>(context,MaterialPageRoute(builder:(_)=>DayEditor(day:d,initial:(ex['$d']??[]).map((e)=>e.copy()).toList(),library:widget.library,newExercise:widget.newExercise)));if(r!=null&&mounted)setState((){days.add(d);ex['$d']=r;});}void save(){final valid=days.where((d)=>(ex['$d']??[]).isNotEmpty).toSet();if(name.text.trim().isEmpty||valid.isEmpty)return;Navigator.pop(context,WorkoutPlanDraft(name:name.text.trim(),weekdays:valid,dayExercises:ex));}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.old==null?'Criar treino':'Editar treino')),body:ListView(padding:const EdgeInsets.all(16),children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nome do treino')),for(var i=1;i<=7;i++)ListTile(title:Text(weekDays[i-1]),subtitle:Text('${ex['$i']?.length??0} exercício(s)'),trailing:const Icon(Icons.chevron_right),onTap:()=>day(i)),FilledButton(onPressed:save,child:const Text('SALVAR TREINO'))]));}
class DayEditor extends StatefulWidget{final int day;final List<Exercise> initial;final List<ExerciseInfo> library;final Future<ExerciseInfo?> Function() newExercise;const DayEditor({super.key,required this.day,required this.initial,required this.library,required this.newExercise});@override State<DayEditor> createState()=>_DayEditorState();}
class _DayEditorState extends State<DayEditor>{late List<Exercise> list;@override void initState(){super.initState();list=widget.initial.map((e){final copy=e.copy();if(copy.imagePath.isEmpty)copy.imagePath=defaultExerciseImage(copy.name);return copy;}).toList();}Future<void> add()async{final e=await showDialog<Exercise>(context:context,builder:(_)=>ExercisePicker(library:widget.library,newExercise:widget.newExercise));if(e!=null&&mounted)setState(()=>list.add(e));}Future<void> edit(int i)async{final e=await showDialog<Exercise>(context:context,builder:(_)=>ExerciseSettings(initial:list[i]));if(e!=null&&mounted)setState(()=>list[i]=e);}@override Widget build(BuildContext context){final children=<Widget>[];for(var i=0;i<list.length;i++){children.add(Card(child:ListTile(leading:_ExerciseThumb(path:list[i].imagePath),title:Text(list[i].name),subtitle:Text('${list[i].muscle} • ${list[i].sets}×${list[i].reps}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>edit(i),icon:const Icon(Icons.tune)),IconButton(onPressed:()=>setState(()=>list.removeAt(i)),icon:const Icon(Icons.delete))]))));}return Scaffold(appBar:AppBar(title:Text(weekDays[widget.day-1]),actions:[TextButton(onPressed:()=>Navigator.pop(context,list),child:const Text('SALVAR'))]),body:Stack(children:[ListView(padding:const EdgeInsets.fromLTRB(16,16,16,92),children:children),Positioned(left:16,right:16,bottom:0,child:SafeArea(top:false,child:Container(padding:const EdgeInsets.only(top:8,bottom:8),color:Theme.of(context).scaffoldBackgroundColor,child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('ADICIONAR EXERCÍCIO'))))))]));}}
class ExercisePicker extends StatefulWidget{final List<ExerciseInfo> library;final Future<ExerciseInfo?> Function() newExercise;const ExercisePicker({super.key,required this.library,required this.newExercise});@override State<ExercisePicker> createState()=>_ExercisePickerState();}
class _ExercisePickerState extends State<ExercisePicker>{late List<ExerciseInfo> list;String query='';String? selected;@override void initState(){super.initState();list=[...widget.library];}Future<void> create()async{final e=await widget.newExercise();if(e!=null&&mounted)setState((){list.add(e);selected=e['name'];});}@override Widget build(BuildContext context){final filtered=list.where((e)=>e['name']!.toLowerCase().contains(query.toLowerCase())).toList()..sort((a,b){final am=muscleGroups.indexOf(a['muscle']!);final bm=muscleGroups.indexOf(b['muscle']!);final group=(am<0?999:am).compareTo(bm<0?999:bm);return group!=0?group:a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase());});final children=<Widget>[TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Pesquisar'),onChanged:(v)=>setState(()=>query=v))];for(final e in filtered){children.add(ListTile(leading:_ExerciseThumb(path:e['imagePath']??''),title:Text(e['name']!),subtitle:Text(e['equipment']!.isEmpty?e['muscle']!:'${e['muscle']} • ${e['equipment']}'),selected:selected==e['name'],onTap:()=>setState(()=>selected=e['name'])));}return AlertDialog(title:const Text('Exercício'),content:SizedBox(width:450,height:420,child:ListView(children:children)),actions:[TextButton(onPressed:create,child:const Text('NOVO')),TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CANCELAR')),FilledButton(onPressed:(){if(selected==null)return;final e=list.firstWhere((x)=>x['name']==selected);Navigator.pop(context,Exercise(id:DateTime.now().microsecondsSinceEpoch.toString(),name:e['name']!,muscle:e['muscle']!,sets:3,reps:10,imagePath:e['imagePath']??''));},child:const Text('ADICIONAR'))]);}}
class _ExerciseThumb extends StatelessWidget{
  final String path;
  const _ExerciseThumb({required this.path});
  @override Widget build(BuildContext context){
    if(path.isEmpty)return const CircleAvatar(radius:26,child:Icon(Icons.fitness_center));
    if(path.startsWith('assets/'))return ClipRRect(
      borderRadius:BorderRadius.circular(10),
      child:SvgPicture.asset(path,width:52,height:52,fit:BoxFit.cover,placeholderBuilder:(_)=>const CircleAvatar(radius:26,child:Icon(Icons.fitness_center))),
    );
    return ClipRRect(
      borderRadius:BorderRadius.circular(10),
      child:Image.file(File(path),width:52,height:52,fit:BoxFit.cover,cacheWidth:160,cacheHeight:160,filterQuality:FilterQuality.low,gaplessPlayback:true,errorBuilder:(_,__,___)=>const CircleAvatar(radius:26,child:Icon(Icons.fitness_center))),
    );
  }
}
class ExerciseSettings extends StatefulWidget{final Exercise initial;const ExerciseSettings({super.key,required this.initial});@override State<ExerciseSettings> createState()=>_ExerciseSettingsState();}
class _ExerciseSettingsState extends State<ExerciseSettings>{late int sets,reps;@override void initState(){super.initState();sets=widget.initial.sets;reps=widget.initial.reps;}@override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial.name),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('Séries: $sets'),Slider(value:sets.toDouble(),min:1,max:12,divisions:11,onChanged:(v)=>setState(()=>sets=v.round())),Text('Repetições: $reps'),Slider(value:reps.toDouble(),min:1,max:30,divisions:29,onChanged:(v)=>setState(()=>reps=v.round()))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CANCELAR')),FilledButton(onPressed:()=>Navigator.pop(context,Exercise(id:widget.initial.id,name:widget.initial.name,muscle:widget.initial.muscle,sets:sets,reps:reps,imagePath:widget.initial.imagePath)),child:const Text('SALVAR'))]);}
class WorkoutExecution extends StatefulWidget{final String name;final int weekday;final List<Exercise> exercises;const WorkoutExecution({super.key,required this.name,required this.weekday,required this.exercises});@override State<WorkoutExecution> createState()=>_WorkoutExecutionState();}
class _WorkoutExecutionState extends State<WorkoutExecution>{
  late List<List<TextEditingController>> controllers;
  late List<List<bool>> done;
  late DateTime workoutDate;

  @override
  void initState(){
    super.initState();
    workoutDate=DateTime.now();
    controllers=widget.exercises.map((e)=>List.generate(e.sets,(_)=>TextEditingController())).toList();
    done=widget.exercises.map((e)=>List<bool>.filled(e.sets,false)).toList();
  }

  @override
  void dispose(){
    for(final row in controllers){for(final c in row){c.dispose();}}
    super.dispose();
  }

  double? kg(int i,int s)=>double.tryParse(controllers[i][s].text.replaceAll(',','.').trim());

  Future<void> _pickWorkoutDate()async{
    final picked=await showDatePicker(context:context,initialDate:workoutDate,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(picked!=null&&mounted)setState(()=>workoutDate=picked);
  }

  Future<void> finish()async{
    for(var i=0;i<widget.exercises.length;i++){
      for(var s=0;s<widget.exercises[i].sets;s++){
        final v=kg(i,s);
        if(!done[i][s]||v==null||v<0){
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Informe a carga e conclua todas as séries.')));
          return;
        }
      }
    }
    final completed=<Exercise>[];
    for(var i=0;i<widget.exercises.length;i++){
      final e=widget.exercises[i].copy();
      e.weights=List.generate(e.sets,(s)=>kg(i,s)!);
      e.done=[...done[i]];
      completed.add(e);
    }
    final history=await StorageService.read('workout_history');
    final savedDate=DateTime(workoutDate.year,workoutDate.month,workoutDate.day,DateTime.now().hour,DateTime.now().minute,DateTime.now().second);
    history.add(Workout(id:DateTime.now().microsecondsSinceEpoch.toString(),name:widget.name,date:savedDate.toIso8601String(),weekday:workoutDate.weekday,exercises:completed).toJson());
    await StorageService.write('workout_history',history);
    if(mounted)Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context){
    final children=<Widget>[
      Text('Execução do treino',style:Theme.of(context).textTheme.headlineSmall),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.calendar_month),title:const Text('Data do treino'),subtitle:Text(DateFormat('dd/MM/yyyy').format(workoutDate)),onTap:_pickWorkoutDate),
    ];
    for(var i=0;i<widget.exercises.length;i++){
      final rows=<Widget>[
        if(widget.exercises[i].imagePath.isNotEmpty)
          ClipRRect(borderRadius:BorderRadius.circular(12),child:widget.exercises[i].imagePath.startsWith('assets/')?SvgPicture.asset(widget.exercises[i].imagePath,height:130,width:double.infinity,fit:BoxFit.cover,placeholderBuilder:(_)=>const SizedBox.shrink()):Image.file(File(widget.exercises[i].imagePath),height:130,width:double.infinity,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox.shrink())),
        Text(widget.exercises[i].name,style:Theme.of(context).textTheme.titleLarge),
        Text(widget.exercises[i].muscle)
      ];
      for(var s=0;s<widget.exercises[i].sets;s++){
        rows.add(Row(children:[
          SizedBox(width:60,child:Text('Série ${s+1}')),
          SizedBox(width:85,child:TextField(controller:controllers[i][s],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(hintText:'kg'))),
          Expanded(child:Text('${widget.exercises[i].reps} reps')),
          Checkbox(value:done[i][s],onChanged:(v)=>setState(()=>done[i][s]=v==true))
        ]));
      }
      children.add(AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:rows)));
    }
    children.add(FilledButton(onPressed:finish,child:const Text('FINALIZAR TREINO')));
    return Scaffold(appBar:AppBar(title:Text(widget.name)),body:ListView(padding:const EdgeInsets.all(16),children:children));
  }
}
class HistorySection extends StatefulWidget{
  const HistorySection({super.key});
  @override State<HistorySection> createState()=>_HistorySectionState();
}
enum _GymPeriodMode{week,month}
class _HistorySectionState extends State<HistorySection>{
  List<Workout> history=[];
  String? exercise;
  _GymPeriodMode mode=_GymPeriodMode.week;
  late DateTime period;

  @override
  void initState(){super.initState();period=_weekStart(DateTime.now());load();}
  static DateTime _day(DateTime d)=>DateTime(d.year,d.month,d.day);
  static DateTime _weekStart(DateTime d)=>_day(d).subtract(Duration(days:d.weekday%7));
  static DateTime _monthStart(DateTime d)=>DateTime(d.year,d.month,1);

  Future<void> load()async{
    history=(await StorageService.read('workout_history')).map(Workout.fromJson).toList();
    history.sort((a,b)=>a.date.compareTo(b.date));
    if(mounted)setState((){});
  }

  DateTime get periodStart=>mode==_GymPeriodMode.week?_weekStart(period):_monthStart(period);
  DateTime get periodEnd=>mode==_GymPeriodMode.week?periodStart.add(const Duration(days:7)):DateTime(periodStart.year,periodStart.month+1,1);
  DateTime get currentStart{
    final now=DateTime.now();
    return mode==_GymPeriodMode.week?_weekStart(now):_monthStart(now);
  }
  bool get canGoNext=>periodStart.isBefore(currentStart);
  String get periodLabel{
    if(mode==_GymPeriodMode.week){
      final end=periodEnd.subtract(const Duration(days:1));
      return '${DateFormat('dd/MM').format(periodStart)} – ${DateFormat('dd/MM/yyyy').format(end)}';
    }
    return formatMonthYearPtBr(periodStart);
  }
  void _setMode(_GymPeriodMode next){
    setState((){
      mode=next;
      period=next==_GymPeriodMode.week?_weekStart(DateTime.now()):_monthStart(DateTime.now());
    });
  }
  void _move(int delta){
    setState((){
      period=mode==_GymPeriodMode.week?periodStart.add(Duration(days:7*delta)):DateTime(periodStart.year,periodStart.month+delta,1);
    });
  }

  List<_GymDayPoint?> points(){
    if(exercise==null)return[];
    final byDay=<String,_GymDayPoint>{};
    for(final w in history){
      final d=DateTime.tryParse(w.date);
      if(d==null||d.isBefore(periodStart)||!d.isBefore(periodEnd))continue;
      double? best;
      for(final e in w.exercises.where((e)=>e.name==exercise)){
        for(final v in e.weights){
          if(v.isFinite&&v>0&&(best==null||v>best))best=v;
        }
      }
      if(best==null)continue;
      final key=DateFormat('yyyy-MM-dd').format(d);
      final previous=byDay[key];
      if(previous==null||d.isAfter(previous.date))byDay[key]=_GymDayPoint(d,best,w.id);
    }
    final result=< _GymDayPoint?>[];
    final days=mode==_GymPeriodMode.week?7:periodEnd.difference(periodStart).inDays;
    for(var i=0;i<days;i++){
      final d=periodStart.add(Duration(days:i));
      result.add(byDay[DateFormat('yyyy-MM-dd').format(d)]);
    }
    return result;
  }

  double? previousValue(){
    if(exercise==null)return null;
    DateTime? bestDate;double? bestValue;
    for(final w in history){
      final d=DateTime.tryParse(w.date);if(d==null||!d.isBefore(periodStart))continue;
      double? value;
      for(final e in w.exercises.where((e)=>e.name==exercise)){for(final v in e.weights){if(v.isFinite&&v>0&&(value==null||v>value))value=v;}}
      if(value!=null&&(bestDate==null||d.isAfter(bestDate!))){bestDate=d;bestValue=value;}
    }
    return bestValue;
  }

  double? nextValue(){
    if(exercise==null)return null;
    DateTime? bestDate;double? bestValue;
    for(final w in history){
      final d=DateTime.tryParse(w.date);if(d==null||!d.isAfter(periodEnd))continue;
      double? value;
      for(final e in w.exercises.where((e)=>e.name==exercise)){for(final v in e.weights){if(v.isFinite&&v>0&&(value==null||v>value))value=v;}}
      if(value!=null&&(bestDate==null||d.isBefore(bestDate!))){bestDate=d;bestValue=value;}
    }
    return bestValue;
  }

  List<_GymRecord> records(){
    return points().whereType<_GymDayPoint>()
      .map((p)=>_GymRecord(p.workoutId,p.date,p.value)).toList()
      ..sort((a,b)=>b.date.compareTo(a.date));
  }

  Workout? _workout(String id)=>history.cast<Workout?>().firstWhere((w)=>w?.id==id,orElse:()=>null);

  Future<void> _editRecord(_GymRecord record)async{
    final workout=_workout(record.workoutId);
    if(workout==null||exercise==null)return;
    final target=workout.exercises.cast<Exercise?>().firstWhere((e)=>e?.name==exercise,orElse:()=>null);
    if(target==null)return;
    final controllers=List.generate(target.weights.length,(i)=>TextEditingController(text:target.weights[i].toString()));
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:Text('Editar registro • ${target.name}'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        for(var i=0;i<controllers.length;i++)Padding(
          padding:const EdgeInsets.only(bottom:8),
          child:TextField(controller:controllers[i],keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Série ${i+1} (kg)')),
        ),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Salvar')),
      ],
    ));
    if(ok==true){
      final values=controllers.map((c)=>double.tryParse(c.text.replaceAll(',','.').trim())??0).toList();
      for(final c in controllers)c.dispose();
      if(values.any((v)=>v<0||!v.isFinite))return;
      target.weights=values;
      await StorageService.write('workout_history',history.map((e)=>e.toJson()).toList());
      if(mounted)setState((){});
    }else{
      for(final c in controllers)c.dispose();
    }
  }

  Future<void> _deleteRecord(_GymRecord record)async{
    final workout=_workout(record.workoutId);
    if(workout==null||exercise==null)return;
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Excluir registro?'),
      content:Text('Excluir o registro de ${exercise} em ${DateFormat('dd/MM/yyyy').format(record.date)}?'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Excluir')),
      ],
    ));
    if(ok!=true)return;
    workout.exercises.removeWhere((e)=>e.name==exercise);
    if(workout.exercises.isEmpty)history.removeWhere((w)=>w.id==workout.id);
    await StorageService.write('workout_history',history.map((e)=>e.toJson()).toList());
    if(mounted)setState((){});
  }

  @override
  Widget build(BuildContext context){
    if(history.isEmpty)return AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Evolução de carga',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),
      const Text('Conclua um treino com cargas registradas para começar a acompanhar sua evolução.')
    ]));
    final names=history.expand((w)=>w.exercises.map((e)=>e.name)).where((n)=>n.trim().isNotEmpty).toSet().toList()..sort((a,b){
      final ae=history.expand((w)=>w.exercises).firstWhere((e)=>e.name==a);
      final be=history.expand((w)=>w.exercises).firstWhere((e)=>e.name==b);
      final am=muscleGroups.indexOf(ae.muscle),bm=muscleGroups.indexOf(be.muscle);
      final group=(am<0?999:am).compareTo(bm<0?999:bm);
      return group!=0?group:a.toLowerCase().compareTo(b.toLowerCase());
    });
    exercise=names.contains(exercise)?exercise:(names.isEmpty?null:names.first);
    final chartData=points();
    final recordList=records();
    final registered=chartData.whereType<_GymDayPoint>().length;
    return AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Evolução de carga',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),
      SegmentedButton<_GymPeriodMode>(
        segments:const[
          ButtonSegment(value:_GymPeriodMode.week,label:Text('Semanal')),
          ButtonSegment(value:_GymPeriodMode.month,label:Text('Mensal')),
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
      _ExerciseSelector(
        selected:exercise,
        options:names.map((n){
          final match=history.expand((w)=>w.exercises).firstWhere((e)=>e.name==n,orElse:()=>Exercise(id:'',name:n,muscle:'Outros',sets:1,reps:1));
          return <String,String>{'name':n,'muscle':match.muscle,'imagePath':match.imagePath.isNotEmpty?match.imagePath:defaultExerciseImage(n)};
        }).toList(),
        onChanged:(v)=>setState(()=>exercise=v),
      ),
      const SizedBox(height:6),
      const Text('Uma carga por dia • treino mais recente do dia'),
      const SizedBox(height:6),
      if(chartData.isNotEmpty)_GymChart(data:chartData,color:Theme.of(context).colorScheme.primary,startDate:periodStart,previousValue:previousValue(),nextValue:nextValue())
      else const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('Nenhum registro de carga neste período.')),
      if(registered>0)Text('${registered} dia(s) com registro • maior carga do treino selecionado'),
      const SizedBox(height:8),
      Text('Registros do período',style:Theme.of(context).textTheme.titleMedium),
      if(recordList.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('Nenhum registro neste período.')),
      for(final r in recordList)ListTile(
        contentPadding:EdgeInsets.zero,
        title:Text('${DateFormat('dd/MM/yyyy HH:mm').format(r.date)} • ${r.value.toStringAsFixed(r.value.truncateToDouble()==r.value?0:1)} kg'),
        subtitle:Text(exercise!),
        trailing:PopupMenuButton<String>(
          onSelected:(v){if(v=='edit')_editRecord(r);if(v=='delete')_deleteRecord(r);},
          itemBuilder:(_)=>const[
            PopupMenuItem(value:'edit',child:Text('Editar')),
            PopupMenuItem(value:'delete',child:Text('Excluir')),
          ],
        ),
      ),
      Text('${history.length} treino(s) concluído(s).'),
    ]));
  }
}
class _ExerciseSelector extends StatefulWidget{
  final String? selected;
  final List<ExerciseInfo> options;
  final ValueChanged<String> onChanged;
  const _ExerciseSelector({required this.selected,required this.options,required this.onChanged});
  @override State<_ExerciseSelector> createState()=>_ExerciseSelectorState();
}
class _ExerciseSelectorState extends State<_ExerciseSelector>{
  bool expanded=false;
  double dragOffset=0;
  @override Widget build(BuildContext context){
    final selected=widget.selected??'Nenhum exercício';
    return AnimatedContainer(
      duration:const Duration(milliseconds:280),
      curve:Curves.easeOutCubic,
      height:expanded?360:58,
      clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(18),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),
      child:Column(children:[
        GestureDetector(
          behavior:HitTestBehavior.opaque,
          onTap:()=>setState(()=>expanded=true),
          onVerticalDragUpdate:(d){if(expanded&&d.delta.dy>0)setState(()=>dragOffset+=d.delta.dy);},
          onVerticalDragEnd:(_){if(expanded&&dragOffset>45)setState((){expanded=false;dragOffset=0;});else setState(()=>dragOffset=0);},
          child:Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),child:Column(children:[
            if(expanded)Container(width:42,height:4,margin:const EdgeInsets.only(bottom:7),decoration:BoxDecoration(color:Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:.45),borderRadius:BorderRadius.circular(4))),
            Row(children:[Expanded(child:Text(selected,style:Theme.of(context).textTheme.titleMedium)),Icon(expanded?Icons.keyboard_arrow_down:Icons.keyboard_arrow_up)]),
          ])),
        ),
        if(expanded)Expanded(child:ListView.builder(padding:const EdgeInsets.fromLTRB(8,0,8,8),itemCount:widget.options.length,itemBuilder:(context,i){final e=widget.options[i];return ListTile(dense:true,leading:_ExerciseThumb(path:e['imagePath']??''),title:Text(e['name']!),subtitle:Text(e['muscle']!),selected:e['name']==widget.selected,onTap:(){widget.onChanged(e['name']!);setState(()=>dragOffset=0);});}))
      ])
    );
  }
}
class _GymDayPoint{
  final DateTime date;final double value;final String workoutId;
  _GymDayPoint(this.date,this.value,this.workoutId);
}
class _GymRecord{
  final String workoutId;final DateTime date;final double value;
  _GymRecord(this.workoutId,this.date,this.value);
}
class _GymChart extends StatefulWidget{
  final List<_GymDayPoint?> data;final Color color;final DateTime startDate;final double? previousValue;final double? nextValue;
  const _GymChart({required this.data,required this.color,required this.startDate,this.previousValue,this.nextValue});
  @override State<_GymChart> createState()=>_GymChartState();
}
class _GymChartState extends State<_GymChart>{
  double? selectionX;
  @override Widget build(BuildContext context)=>SizedBox(
    height:250,
    child:GestureDetector(
      behavior:HitTestBehavior.opaque,
      onTapDown:(d)=>setState(()=>selectionX=d.localPosition.dx),
      onHorizontalDragUpdate:(d)=>setState(()=>selectionX=d.localPosition.dx),
      child:CustomPaint(
        painter:_GymChartPainter(widget.data,widget.color,Theme.of(context).colorScheme.onSurfaceVariant,Directionality.of(context),widget.startDate,widget.previousValue,widget.nextValue,selectionX),
        child:const SizedBox.expand(),
      ),
    ),
  );
}
class _GymChartPainter extends CustomPainter{
  final List<_GymDayPoint?> data;final Color color;final Color labelColor;final ui.TextDirection textDirection;final DateTime startDate;final double? previousValue;final double? nextValue;final double? selectionX;
  _GymChartPainter(this.data,this.color,this.labelColor,this.textDirection,this.startDate,this.previousValue,this.nextValue,this.selectionX);
  @override void paint(Canvas c,Size s){
    if(data.isEmpty)return;const left=42.0,right=12.0,top=26.0,bottom=40.0;
    final w=math.max(1.0,s.width-left-right),h=math.max(1.0,s.height-top-bottom);
    final pts=<MapEntry<int,_GymDayPoint>>[];for(var k=0;k<data.length;k++){final p=data[k];if(p!=null)pts.add(MapEntry(k,p));}
    if(pts.isEmpty){_txt(c,'Nada registrado',Offset(s.width/2,s.height/2-10),14,labelColor,TextAlign.center);return;}
    final vals=<double>[];if(previousValue!=null)vals.add(previousValue!);if(nextValue!=null)vals.add(nextValue!);for(final p in data)if(p!=null)vals.add(p.value);
    final minV=vals.reduce(math.min),maxV=vals.reduce(math.max),raw=math.max(.01,maxV-minV),pad=raw*.12,lo=minV-pad,hi=maxV+pad;
    double x(int i)=>data.length==1?left+w/2:left+w*i/(data.length-1);double y(double v)=>top+h-(v-lo)/(hi-lo)*h;
    final grid=Paint()..color=color.withValues(alpha:.14),ticks=Paint()..color=color.withValues(alpha:.10),axis=Paint()..color=color.withValues(alpha:.35);
    for(var j=0;j<=4;j++){final yy=top+h*j/4;c.drawLine(Offset(left,yy),Offset(s.width-right,yy),grid);_txt(c,'${(hi-(hi-lo)*j/4).toStringAsFixed(1)} kg',Offset(2,yy-7),9,labelColor,TextAlign.left);}
    for(var k=0;k<data.length;k++){final xx=x(k);c.drawLine(Offset(xx,top),Offset(xx,s.height-bottom),ticks);final show=data.length<=7||k==0||k==data.length-1||k%5==0;if(show)_txt(c,DateFormat('dd/MM').format(startDate.add(Duration(days:k))),Offset(xx,s.height-bottom+8),9,labelColor,TextAlign.center);}
    final line=Paint()..color=color..strokeWidth=3..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;final path=Path();
    if(previousValue!=null){path.moveTo(left,y(previousValue!));path.lineTo(x(pts.first.key),y(pts.first.value.value));}
    for(var k=1;k<pts.length;k++){path.moveTo(x(pts[k-1].key),y(pts[k-1].value.value));path.lineTo(x(pts[k].key),y(pts[k].value.value));}
    if(nextValue!=null){path.moveTo(x(pts.last.key),y(pts.last.value.value));path.lineTo(s.width-right,y(nextValue!));}
    if(previousValue==null&&pts.length==1&&nextValue==null){path.moveTo(x(pts.first.key),y(pts.first.value.value));}c.drawPath(path,line);
    int? selected;
    if(selectionX!=null&&pts.isNotEmpty){selected=pts.first.key;var best=(x(selected!)-selectionX!).abs();for(final e in pts){final d=(x(e.key)-selectionX!).abs();if(d<best){best=d;selected=e.key;}}}
    for(final e in pts){final yy=y(e.value.value),big=e.key==selected;c.drawCircle(Offset(x(e.key),yy),big?9:4,Paint()..color=color);if(big){_txt(c,DateFormat('dd/MM/yyyy').format(e.value.date),Offset(x(e.key),math.max(top,yy-40)),11,labelColor,TextAlign.center);_txt(c,'${e.value.value.toStringAsFixed(e.value.value.truncateToDouble()==e.value.value?0:1)} kg',Offset(x(e.key),math.max(top+14,yy-22)),11,labelColor,TextAlign.center);}}
    c.drawLine(Offset(left,top),Offset(left,s.height-bottom),axis);c.drawLine(Offset(left,s.height-bottom),Offset(s.width-right,s.height-bottom),axis);
  }
  void _txt(Canvas c,String v,Offset p,double size,Color col,TextAlign a){final tp=TextPainter(text:TextSpan(text:v,style:TextStyle(fontSize:size,color:col,fontWeight:FontWeight.w500)),textDirection:textDirection,textAlign:a)..layout(maxWidth:100);tp.paint(c,Offset((a==TextAlign.center?p.dx-tp.width/2:p.dx).clamp(0.0,10000.0).toDouble(),p.dy));}
  @override bool shouldRepaint(covariant _GymChartPainter o)=>o.data!=data||o.color!=color||o.previousValue!=previousValue||o.nextValue!=nextValue||o.selectionX!=selectionX||o.startDate!=startDate;
}