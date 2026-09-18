import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_card.dart';

const expenseCategories=['Alimentação','Transporte','Moradia','Lazer','Educação','Saúde','Compras','Outros'];
const incomeCategories=['Salário','Freelance','Investimentos','Outros'];

class FinanceScreen extends StatefulWidget{const FinanceScreen({super.key});@override State<FinanceScreen> createState()=>_FinanceScreenState();}

class _FinanceScreenState extends State<FinanceScreen>{
  List<MoneyTransaction> items=[];
  DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  bool loading=true;

  @override void initState(){super.initState();_load();}

  Future<void> _load()async{
    items=(await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList();
    _refreshStatuses();
    await _ensureRecurring();
    _refreshStatuses();
    await _save();
    if(mounted)setState(()=>loading=false);
  }

  void _refreshStatuses(){
    final today=DateTime.now();
    final d0=DateTime(today.year,today.month,today.day);
    for(final x in items){
      if(x.isCancelled||x.isPaid)continue;
      final d=DateTime.tryParse(x.dueDate);
      if(d!=null&&d.isBefore(d0))x.paymentStatus='overdue';
      else x.paymentStatus='pending';
    }
  }

  Future<void> _ensureRecurring()async{
    final groups=<String,MoneyTransaction>{};
    for(final x in items){if(x.isRecurring&&x.recurrenceGroupId!=null)groups[x.recurrenceGroupId!]=x;}
    final horizon=DateTime(DateTime.now().year,DateTime.now().month+36,1);
    for(final master in groups.values){
      if(master.recurrenceFrequency!='monthly')continue;
      final start=DateTime.tryParse(master.recurrenceStartDate.isEmpty?master.dueDate:master.recurrenceStartDate);
      if(start==null)continue;
      final end=master.recurrenceEndDate==null?null:DateTime.tryParse(master.recurrenceEndDate!);
      var cursor=DateTime(start.year,start.month,start.day);
      while(cursor.isBefore(horizon)){
        if(end!=null&&!cursor.isBefore(end))break;
        final date=DateFormat('yyyy-MM-dd').format(cursor);
        final exists=items.any((x)=>x.isRecurring&&x.recurrenceGroupId==master.recurrenceGroupId&&x.dueDate==date);
        if(!exists){
          items.add(MoneyTransaction(
            id:'r-${master.recurrenceGroupId}-$date',
            date:date,description:master.description,category:master.category,amount:master.amount,income:false,
            paymentStatus:'pending',isRecurring:true,recurrenceGroupId:master.recurrenceGroupId,
            recurrenceFrequency:'monthly',recurrenceStartDate:master.recurrenceStartDate,dueDate:date,
          ));
        }
        cursor=DateTime(cursor.year,cursor.month+1,math.min(start.day,DateTime(cursor.year,cursor.month+2,0).day).toInt());
      }
    }
  }

  Future<void> _save()=>StorageService.write('finance',items.map((e)=>e.toJson()).toList());
  String money(double v)=>'R\$ ${v.toStringAsFixed(2).replaceAll('.',',')}';
  String _ym(DateTime d)=>DateFormat('yyyy-MM').format(d);
  DateTime _date(String s)=>DateTime.tryParse(s)??DateTime.now();

  List<MoneyTransaction> _month(DateTime d)=>items.where((x)=>!x.isCancelled&&_ym(_date(x.dueDate))==_ym(d)).toList();
  double _sum(Iterable<MoneyTransaction> xs,{bool income=false,bool paidOnly=false})=>xs.where((x)=>x.income==income&&(!paidOnly||x.isPaid)).fold(0.0,(a,x)=>a+x.amount);
  double _balance()=>items.where((x)=>x.isPaid&&!x.isCancelled).fold(0.0,(a,x)=>a+(x.income?x.amount:-x.amount));

  Future<DateTime?> _pickDate(DateTime initial)async=>showDatePicker(context:context,initialDate:initial,firstDate:DateTime(2020),lastDate:DateTime(2100));

  Future<void> _single(bool income,{MoneyTransaction? editing})async{
    final d=TextEditingController(text:editing?.description??'');
    final a=TextEditingController(text:editing==null?'':editing.amount.toStringAsFixed(2));
    String cat=editing?.category??(income?'Salário':'Outros');
    bool paid=editing?.isPaid??false;
    DateTime due=editing==null?DateTime.now():_date(editing.dueDate);
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(editing==null?(income?'Nova entrada':'Nova despesa'):'Editar movimentação'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:d,decoration:const InputDecoration(labelText:'Descrição')),
        TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Valor')),
        DropdownButtonFormField<String>(initialValue:cat,items:(income?incomeCategories:expenseCategories).map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setD(()=>cat=v);},decoration:const InputDecoration(labelText:'Categoria')),
        ListTile(contentPadding:EdgeInsets.zero,title:Text('Vencimento: ${DateFormat('dd/MM/yyyy').format(due)}'),trailing:const Icon(Icons.calendar_month),onTap:()async{final r=await _pickDate(due);if(r!=null)setD(()=>due=r);}),
        if(!income)SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Foi pago?'),value:paid,onChanged:(v)=>setD(()=>paid=v)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvar'))],
    )));
    final value=double.tryParse(a.text.replaceAll(',','.'));
    final description=d.text.trim();d.dispose();a.dispose();
    if(ok!=true||description.isEmpty||value==null||value<=0)return;
    final date=DateFormat('yyyy-MM-dd').format(due);
    if(editing!=null){
      editing.description=description;editing.category=cat;editing.amount=value;editing.totalAmount=value;editing.installmentAmount=value;editing.dueDate=date;editing.date=date;
      if(!income){editing.paymentStatus=paid?'paid':'pending';editing.paidDate=paid?DateFormat('yyyy-MM-dd').format(DateTime.now()):null;}
    }else{
      items.add(MoneyTransaction(id:DateTime.now().microsecondsSinceEpoch.toString(),date:date,description:description,category:cat,amount:value,income:income,paymentStatus:income?'paid':(paid?'paid':'pending'),dueDate:date,paidDate:paid?DateFormat('yyyy-MM-dd').format(DateTime.now()):null));
    }
    await _scheduleReminder(items.lastWhere((x)=>x.description==description&&x.dueDate==date&&x.amount==value));
    await _save();if(mounted)setState((){});
  }

  Future<void> _installment({MoneyTransaction? editing})async{
    final d=TextEditingController(text:editing?.description??'');
    final amount=TextEditingController(text:editing==null?'':editing.installmentAmount.toStringAsFixed(2));
    final n=TextEditingController(text:editing?.totalInstallments.toString()??'2');
    String mode='total';String cat=editing?.category??'Outros';bool paid=editing?.isPaid??false;
    DateTime due=editing==null?DateTime.now():_date(editing.dueDate);
    if(editing!=null)mode='parcel';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(editing==null?'Compra parcelada':'Editar parcela'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:d,decoration:const InputDecoration(labelText:'Descrição')),
        DropdownButtonFormField<String>(initialValue:mode,items:const[DropdownMenuItem(value:'total',child:Text('Informar valor total')),DropdownMenuItem(value:'parcel',child:Text('Informar valor por parcela'))],onChanged:(v){if(v!=null)setD(()=>mode=v);},decoration:const InputDecoration(labelText:'O valor informado é')),
        TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:mode=='total'?'Valor total':'Valor da parcela')),
        TextField(controller:n,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Número de parcelas')),
        DropdownButtonFormField<String>(initialValue:cat,items:expenseCategories.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setD(()=>cat=v);},decoration:const InputDecoration(labelText:'Categoria')),
        ListTile(contentPadding:EdgeInsets.zero,title:Text('Vencimento: ${DateFormat('dd/MM/yyyy').format(due)}'),trailing:const Icon(Icons.calendar_month),onTap:()async{final r=await _pickDate(due);if(r!=null)setD(()=>due=r);}),
        if(editing!=null)SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Foi pago?'),value:paid,onChanged:(v)=>setD(()=>paid=v)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvar'))],
    )));
    final raw=double.tryParse(amount.text.replaceAll(',','.'));final count=int.tryParse(n.text);final desc=d.text.trim();d.dispose();amount.dispose();n.dispose();
    if(ok!=true||raw==null||raw<=0||count==null||count<2||desc.isEmpty)return;
    if(editing!=null){
      editing.description=desc;editing.category=cat;editing.totalInstallments=count;editing.dueDate=DateFormat('yyyy-MM-dd').format(due);editing.date=editing.dueDate;
      editing.installmentAmount=mode=='total'?raw/count:raw;editing.amount=editing.installmentAmount;editing.totalAmount=mode=='total'?raw:raw*count;editing.paymentStatus=paid?'paid':'pending';editing.paidDate=paid?DateFormat('yyyy-MM-dd').format(DateTime.now()):null;
      await _save();if(mounted)setState((){});return;
    }
    final group=DateTime.now().microsecondsSinceEpoch.toString();final total=mode=='total'?raw:raw*count;final each=mode=='total'?raw/count:raw;double used=0;
    for(var i=1;i<=count;i++){
      final dd=DateTime(due.year,due.month+i-1,math.min(due.day,DateTime(due.year,due.month+i,0).day).toInt());
      final value=i==count?double.parse((total-used).toStringAsFixed(2)):double.parse(each.toStringAsFixed(2));used+=value;
      final ds=DateFormat('yyyy-MM-dd').format(dd);
      final x=MoneyTransaction(id:'$group-$i',date:ds,description:desc,category:cat,amount:value,income:false,paymentStatus:'pending',isInstallment:true,installmentGroupId:group,totalInstallments:count,installmentNumber:i,totalAmount:total,installmentAmount:value,dueDate:ds);
      items.add(x);await _scheduleReminder(x);
    }
    await _save();if(mounted)setState((){});
  }

  Future<void> _recurring({MoneyTransaction? editing})async{
    final d=TextEditingController(text:editing?.description??'');final a=TextEditingController(text:editing?.amount.toStringAsFixed(2)??'');
    String cat=editing?.category??'Outros';bool paid=editing?.isPaid??false;DateTime due=editing==null?DateTime.now():_date(editing.dueDate);
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(editing==null?'Despesa recorrente':'Editar recorrência'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:d,decoration:const InputDecoration(labelText:'Descrição')),
        TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Valor mensal')),
        DropdownButtonFormField<String>(initialValue:cat,items:expenseCategories.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setD(()=>cat=v);},decoration:const InputDecoration(labelText:'Categoria')),
        ListTile(contentPadding:EdgeInsets.zero,title:Text('Dia de pagamento: ${due.day}'),trailing:const Icon(Icons.calendar_month),onTap:()async{final r=await _pickDate(due);if(r!=null)setD(()=>due=r);}),
        if(editing!=null)SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Foi pago?'),value:paid,onChanged:(v)=>setD(()=>paid=v)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvar'))],
    )));
    final value=double.tryParse(a.text.replaceAll(',','.'));final desc=d.text.trim();d.dispose();a.dispose();
    if(ok!=true||value==null||value<=0||desc.isEmpty)return;
    if(editing!=null){
      final group=editing.recurrenceGroupId;
      for(final x in items.where((e)=>e.isRecurring&&e.recurrenceGroupId==group)){
        if(x.isPaid){if(x.id==editing.id){x.description=desc;x.category=cat;x.amount=value;}}else{x.description=desc;x.category=cat;x.amount=value;}
      }
      editing.dueDate=DateFormat('yyyy-MM-dd').format(due);editing.date=editing.dueDate;editing.paymentStatus=paid?'paid':'pending';
    }else{
      final group=DateTime.now().microsecondsSinceEpoch.toString();final ds=DateFormat('yyyy-MM-dd').format(due);
      final x=MoneyTransaction(id:'r-$group-$ds',date:ds,description:desc,category:cat,amount:value,income:false,paymentStatus:'pending',isRecurring:true,recurrenceGroupId:group,recurrenceFrequency:'monthly',recurrenceStartDate:ds,dueDate:ds);
      items.add(x);await _scheduleReminder(x);
    }
    await _ensureRecurring();await _save();if(mounted)setState((){});
  }

  Future<void> _scheduleReminder(MoneyTransaction x)async{
    if(x.income||x.isCancelled||x.isPaid)return;
    final d=_date(x.dueDate);final scheduled=DateTime(d.year,d.month,d.day,9);
    final id=x.id.hashCode.abs();
    await NotificationService.schedule(id:id,date:scheduled,title:'Pagamento pendente',body:'${x.description} — ${money(x.amount)} vence hoje e ainda não foi marcado como pago.');
  }

  Future<void> _toggle(MoneyTransaction x)async{
    if(x.isPaid){x.paymentStatus='pending';x.paidDate=null;}else{x.paymentStatus='paid';x.paidDate=DateFormat('yyyy-MM-dd').format(DateTime.now());await NotificationService.cancel(x.id.hashCode.abs());}
    await _save();if(mounted)setState((){});
  }

  Future<void> _edit(MoneyTransaction x)async{
    if(x.isInstallment)await _installment(editing:x);
    else if(x.isRecurring)await _recurring(editing:x);
    else await _single(x.income,editing:x);
  }

  Future<void> _remove(MoneyTransaction x)async{
    if(x.isInstallment){
      for(final e in items.where((e)=>e.isInstallment&&e.installmentGroupId==x.installmentGroupId&&!e.isPaid)){e.paymentStatus='cancelled';await NotificationService.cancel(e.id.hashCode.abs());}
    }else if(x.isRecurring){
      for(final e in items.where((e)=>e.isRecurring&&e.recurrenceGroupId==x.recurrenceGroupId&&!e.isPaid)){e.paymentStatus='cancelled';await NotificationService.cancel(e.id.hashCode.abs());}
    }else{
      if(x.isPaid){items.removeWhere((e)=>e.id==x.id);}else{x.paymentStatus='cancelled';await NotificationService.cancel(x.id.hashCode.abs());}
    }
    await _save();if(mounted)setState((){});
  }

  Future<void> _menu()async{
    final choice=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      ListTile(title:const Text('Nova entrada'),onTap:()=>Navigator.pop(c,'in')),
      ListTile(title:const Text('Nova despesa'),onTap:()=>Navigator.pop(c,'out')),
      ListTile(title:const Text('Compra parcelada'),onTap:()=>Navigator.pop(c,'inst')),
      ListTile(title:const Text('Despesa recorrente'),onTap:()=>Navigator.pop(c,'rec')),
    ])));
    if(choice=='in')await _single(true);else if(choice=='out')await _single(false);else if(choice=='inst')await _installment();else if(choice=='rec')await _recurring();
  }

  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    final cur=_month(month);
    final incPaid=_sum(cur,income:true,paidOnly:true),outPaid=_sum(cur,paidOnly:true);
    final projectedOut=_sum(cur,paidOnly:false),projectedBalance=_sum(cur,income:true)-projectedOut;
    final cats=<String,double>{};for(final x in cur.where((x)=>!x.income)){cats[x.category]=(cats[x.category]??0)+x.amount;}
    final months=List.generate(6,(i)=>DateTime(month.year,month.month-5+i));
    return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[Expanded(child:Text('Financeiro',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold))),FilledButton.icon(onPressed:_menu,icon:const Icon(Icons.add),label:const Text('Adicionar'))]),
      AppCard(child:Row(children:[IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1)),icon:const Icon(Icons.chevron_left)),Expanded(child:Text(DateFormat('MMMM yyyy','pt_BR').format(month),textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1)),icon:const Icon(Icons.chevron_right))])),
      Row(children:[Expanded(child:_metric('Entradas pagas',incPaid)),Expanded(child:_metric('Despesas pagas',outPaid))]),
      Row(children:[Expanded(child:_metric('Saldo atual',_balance())),Expanded(child:_metric('Próximo/previsto',projectedOut))]),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Previsão do mês',style:Theme.of(context).textTheme.titleLarge),Text('Despesas previstas: ${money(projectedOut)}'),Text('Saldo projetado: ${money(projectedBalance)}'),Text('Pendentes: ${money(cur.where((x)=>!x.income&&!x.isPaid).fold(0.0,(a,x)=>a+x.amount))}')])) ,
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Entradas x despesas — 6 meses',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),SizedBox(height:200,child:CustomPaint(painter:_FinanceChart(months,items,Theme.of(context).colorScheme.primary),child:const SizedBox.expand()))])),
      if(cats.isNotEmpty)AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Despesas por categoria',style:Theme.of(context).textTheme.titleLarge),for(final e in cats.entries)_category(e.key,e.value,cats.values.fold(0.0,(a,b)=>a+b))])),
      const SizedBox(height:8),Text('Movimentações',style:Theme.of(context).textTheme.titleLarge),
      if(cur.isEmpty)const AppCard(child:Text('Nenhuma movimentação neste mês.')),
      for(final x in cur)_movement(x),
    ]));
  }

  Widget _metric(String l,double v)=>AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(money(v),style:const TextStyle(fontWeight:FontWeight.bold)),Text(l,style:Theme.of(context).textTheme.bodySmall)]));
  Widget _category(String n,double v,double total)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(n),Text(money(v))]),LinearProgressIndicator(value:total==0?0:v/total)]));
  Widget _movement(MoneyTransaction x)=>AppCard(child:ListTile(contentPadding:EdgeInsets.zero,title:Text(x.description),subtitle:Text('${money(x.amount)} • Venc. ${DateFormat('dd/MM/yyyy').format(_date(x.dueDate))} • ${x.isPaid?'Pago':x.isOverdue?'Atrasado':'Previsto'}${x.isInstallment?' • Parcela ${x.installmentNumber}/${x.totalInstallments}':''}${x.isRecurring?' • Recorrente':''}'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='pay')_toggle(x);if(v=='edit')_edit(x);if(v=='delete')_remove(x);},itemBuilder:(_)=>const[PopupMenuItem(value:'pay',child:Text('Marcar pago/previsto')),PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir futuras'))])));

}

class _FinanceChart extends CustomPainter{
 final List<DateTime> months;final List<MoneyTransaction> items;final Color color;
 _FinanceChart(this.months,this.items,this.color);
 @override void paint(Canvas c,Size s){
   final inc=<double>[],out=<double>[];
   for(final m in months){final k=DateFormat('yyyy-MM').format(m);inc.add(items.where((x)=>!x.isCancelled&&x.income&&x.date.startsWith(k)).fold(0.0,(a,x)=>a+x.amount));out.add(items.where((x)=>!x.isCancelled&&!x.income&&x.dueDate.startsWith(k)).fold(0.0,(a,x)=>a+x.amount));}
   final maxV=[...inc,...out].fold<double>(0.0,(a,b)=>math.max(a,b).toDouble());final range=maxV<=0?1.0:maxV;final left=24.0,right=12.0,top=20.0,bottom=28.0;final w=math.max(1.0,s.width-left-right).toDouble(),h=math.max(1.0,s.height-top-bottom).toDouble();
   final p1=Paint()..color=color..strokeWidth=3..style=PaintingStyle.stroke;final p2=Paint()..color=Colors.grey..strokeWidth=3..style=PaintingStyle.stroke;
   void line(List<double> values,Paint p){final path=Path();for(var i=0;i<values.length;i++){final x=values.length==1?left+w/2:left+i*w/(values.length-1);final y=top+h-values[i]/range*h;if(i==0)path.moveTo(x,y);else path.lineTo(x,y);c.drawCircle(Offset(x,y),4,Paint()..color=p.color);}c.drawPath(path,p);}
   line(inc,p1);line(out,p2);
   for(var i=0;i<months.length;i++){final x=left+i*w/(months.length-1);final tp=TextPainter(text:TextSpan(text:DateFormat('MMM','pt_BR').format(months[i]),style:const TextStyle(fontSize:10)),textDirection:TextDirection.ltr)..layout();tp.paint(c,Offset(x-tp.width/2,s.height-18));}
 }
 @override bool shouldRepaint(covariant _FinanceChart old)=>old.months!=months||old.items!=items||old.color!=color;
}
