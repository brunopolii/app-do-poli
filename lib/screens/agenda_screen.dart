import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_card.dart';

class AgendaScreen extends StatefulWidget { const AgendaScreen({super.key}); @override State<AgendaScreen> createState()=>_AgendaScreenState(); }
class _AgendaScreenState extends State<AgendaScreen> {
  DateTime selected=DateTime.now(); List<AgendaEvent> events=[];
  String get dayKey=>DateFormat('yyyy-MM-dd').format(selected);
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final raw=await StorageService.read('agenda'); events=raw.map(AgendaEvent.fromJson).toList(); if(mounted)setState((){}); }
  Future<void> _save()=>StorageService.write('agenda',events.map((e)=>e.toJson()).toList());
  Future<void> _event({AgendaEvent? existing}) async {
    final title=TextEditingController(text:existing?.title??''); final desc=TextEditingController(text:existing?.description??'');
    TimeOfDay start=existing==null?const TimeOfDay(hour:8,minute:0):_time(existing!.start); TimeOfDay end=existing==null?const TimeOfDay(hour:9,minute:0):_time(existing!.end); bool notify=existing?.description.contains('')==true?true:true;
    final result=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:Text(existing==null?'Novo compromisso':'Editar compromisso'),content:SingleChildScrollView(child:Column(children:[
      TextField(controller:title,autofocus:true,decoration:const InputDecoration(labelText:'Descrição / compromisso')),
      const SizedBox(height:8),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('Horário de início'),trailing:Text(start.format(ctx)),onTap:()async{final x=await showTimePicker(context:ctx,initialTime:start);if(x!=null)set(()=>start=x);}),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('Horário de término'),trailing:Text(end.format(ctx)),onTap:()async{final x=await showTimePicker(context:ctx,initialTime:end);if(x!=null)set(()=>end=x);}),
      SwitchListTile(contentPadding:EdgeInsets.zero,value:notify,onChanged:(x)=>set(()=>notify=x),title:const Text('🔔 Notificação'),subtitle:const Text('Avisar no horário definido')),
      TextField(controller:desc,decoration:const InputDecoration(labelText:'Observação (opcional)')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Salvar'))])));
    if(result!=true||title.text.trim().isEmpty)return;
    final dt=DateTime(selected.year,selected.month,selected.day,start.hour,start.minute); final id=existing==null?DateTime.now().millisecondsSinceEpoch: int.tryParse(existing!.id)??DateTime.now().millisecondsSinceEpoch;
    final e=AgendaEvent(id:id.toString(),date:dayKey,title:title.text.trim(),description:desc.text.trim(),start:_fmt(start),end:_fmt(end));
    if(existing!=null)await NotificationService.cancel(id); setState((){events.removeWhere((x)=>x.id==e.id);events.add(e);}); await _save();
    if(notify)await NotificationService.schedule(id:id,date:dt,title:e.title,body:e.description.isEmpty?'Compromisso agendado':e.description);
  }
  TimeOfDay _time(String v){final p=v.split(':');return TimeOfDay(hour:int.tryParse(p.first)??8,minute:int.tryParse(p.length>1?p[1]:'0')??0);}
  String _fmt(TimeOfDay t)=>'${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
  Future<void> _delete(AgendaEvent e)async{await NotificationService.cancel(int.tryParse(e.id)??0);setState(()=>events.remove(e));await _save();}
  @override Widget build(BuildContext context){final dayEvents=events.where((e)=>e.date==dayKey).toList()..sort((a,b)=>a.start.compareTo(b.start));return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
    Row(children:[Expanded(child:Text('Agenda',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold))),IconButton(onPressed:()=>_event(),icon:const Icon(Icons.add_circle))]),
    CalendarDatePicker(initialDate:selected,firstDate:DateTime(2020),lastDate:DateTime(2100),onDateChanged:(d)=>setState(()=>selected=d)),
    Text(DateFormat("EEEE, dd 'de' MMMM",'pt_BR').format(selected),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),
    if(dayEvents.isEmpty)const AppCard(child:Text('Nenhum compromisso neste dia.')),
    ...dayEvents.map((e)=>AppCard(child:ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Text(e.start.split(':').first)),title:Text(e.title),subtitle:Text('${e.start} - ${e.end}${e.description.isEmpty?'':'\n${e.description}'}'),isThreeLine:e.description.isNotEmpty,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit')_event(existing:e);if(v=='delete')_delete(e);},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))])))),
    const SizedBox(height:8),FilledButton.icon(onPressed:()=>_event(),icon:const Icon(Icons.add),label:const Text('Adicionar compromisso'))]));}
}
