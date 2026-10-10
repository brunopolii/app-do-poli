import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/date_formatters.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_card.dart';

const expenseCategories=['Alimentação','Transporte','Moradia','Lazer','Educação','Saúde','Compras','Outros'];
const incomeCategories=['Salário','Freelance','Investimentos','Outros'];
enum FinancePeriodMode{week,month,semester}

class FinanceScreen extends StatefulWidget{const FinanceScreen({super.key});@override State<FinanceScreen> createState()=>FinanceScreenState();}

class FinanceScreenState extends State<FinanceScreen>{
  List<MoneyTransaction> items=[];
  DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  bool loading=true;
  FinancePeriodMode chartMode=FinancePeriodMode.month;
  DateTime chartAnchor=DateTime(DateTime.now().year,DateTime.now().month);

  @override void initState(){super.initState();_load();}

  Future<void> refresh() async {
    if (mounted) setState(() => loading = true);
    await _load();
  }

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
      if(d!=null&&d.isBefore(d0)) {
        x.paymentStatus='overdue';
      } else {
        x.paymentStatus='pending';
      }
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
            date:date,description:master.description,category:master.category,amount:master.amount,income:master.income,
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

  Future<void> _salary({MoneyTransaction? editing})async{
    final d=TextEditingController(text:editing?.description??'Salário');
    final a=TextEditingController(text:editing?.amount.toStringAsFixed(2)??'');
    DateTime due=editing==null?DateTime(DateTime.now().year,DateTime.now().month,1):_date(editing.dueDate);
    int day=editing?.recurrenceStartDate.isNotEmpty==true?(int.tryParse(editing!.recurrenceStartDate.split('-').last)??due.day):due.day;
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
      title:Text(editing==null?'Cadastrar salário':'Editar salário'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:d,decoration:const InputDecoration(labelText:'Descrição')),
        TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Valor mensal')),
        ListTile(contentPadding:EdgeInsets.zero,title:Text('Dia de recebimento: ${DateFormat('dd/MM/yyyy').format(due)}'),trailing:const Icon(Icons.calendar_month),onTap:()async{final r=await _pickDate(due);if(r!=null)setD((){due=r;day=r.day;});}),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvar'))],
    )));
    final value=double.tryParse(a.text.replaceAll(',','.'));final desc=d.text.trim();d.dispose();a.dispose();
    if(ok!=true||value==null||value<=0||desc.isEmpty)return;
    final now=DateTime.now();
    final group=editing?.recurrenceGroupId??DateTime.now().microsecondsSinceEpoch.toString();
    if(editing!=null){
      for(final x in items.where((e)=>e.isRecurring&&e.income&&e.recurrenceGroupId==group)){
        x.description=desc;x.category='Salário';x.amount=value;x.totalAmount=value;x.installmentAmount=value;
      }
      editing.recurrenceStartDate='${due.year}-${due.month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
      final safeDay=math.min(day,DateUtils.getDaysInMonth(due.year,due.month));
      editing.dueDate=DateFormat('yyyy-MM-dd').format(DateTime(due.year,due.month,safeDay));
      editing.date=editing.dueDate;
    }else{
      final safeDay=math.min(day,DateUtils.getDaysInMonth(now.year,now.month));
      final first=DateTime(now.year,now.month,safeDay);
      final ds=DateFormat('yyyy-MM-dd').format(first);
      final status=first.isAfter(DateTime(now.year,now.month,now.day))?'pending':'paid';
      items.add(MoneyTransaction(id:'r-$group-$ds',date:ds,description:desc,category:'Salário',amount:value,income:true,paymentStatus:status,isRecurring:true,recurrenceGroupId:group,recurrenceFrequency:'monthly',recurrenceStartDate:ds,dueDate:ds,paidDate:status=='paid'?DateFormat('yyyy-MM-dd').format(first):null));
    }
    await _ensureRecurring();await _save();if(mounted)setState((){});
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

  Future<void> _edit(MoneyTransaction x) async {
    if (x.isInstallment) {
      await _installment(editing: x);
    } else if (x.isRecurring && x.income) {
      await _salary(editing: x);
    } else if (x.isRecurring) {
      await _recurring(editing: x);
    } else {
      await _single(x.income, editing: x);
    }
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

  Future<void> _menu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Nova entrada'), onTap: () => Navigator.pop(c, 'in')),
            ListTile(title: const Text('Nova despesa'), onTap: () => Navigator.pop(c, 'out')),
            ListTile(title: const Text('Compra parcelada'), onTap: () => Navigator.pop(c, 'inst')),
            ListTile(title: const Text('Despesa recorrente'), onTap: () => Navigator.pop(c, 'rec')),
            ListTile(title: const Text('Salário mensal'), onTap: () => Navigator.pop(c, 'salary')),
          ],
        ),
      ),
    );
    if (choice == 'in') {
      await _single(true);
    } else if (choice == 'out') {
      await _single(false);
    } else if (choice == 'inst') {
      await _installment();
    } else if (choice == 'rec') {
      await _recurring();
    } else if (choice == 'salary') {
      await _salary();
    }
  }

  DateTime get _chartCurrentMonth=>DateTime(DateTime.now().year,DateTime.now().month);
  DateTime _weekStart(DateTime d)=>DateTime(d.year,d.month,d.day).subtract(Duration(days:d.weekday%7));
  DateTime get _chartStart{
    if(chartMode==FinancePeriodMode.week)return _weekStart(DateTime(chartAnchor.year,chartAnchor.month,chartAnchor.day));
    if(chartMode==FinancePeriodMode.month)return DateTime(chartAnchor.year,chartAnchor.month,1);
    return DateTime(chartAnchor.year,chartAnchor.month-5,1);
  }
  DateTime get _chartFullEnd{
    if(chartMode==FinancePeriodMode.week)return _chartStart.add(const Duration(days:7));
    return DateTime(chartAnchor.year,chartAnchor.month+1,1);
  }
  DateTime get _chartEnd{
    // Sempre mostra o período completo, inclusive os dias futuros.
    return _chartFullEnd;
  }
  bool get _chartCanNext{
    final current=chartMode==FinancePeriodMode.week?_weekStart(DateTime.now()):_chartCurrentMonth;
    return _chartStart.isBefore(current);
  }
  String get _chartLabel{
    if(chartMode==FinancePeriodMode.week){
      final end=_chartEnd.subtract(const Duration(days:1));
      return '${DateFormat('dd/MM').format(_chartStart)} – ${DateFormat('dd/MM/yyyy').format(end)}';
    }
    if(chartMode==FinancePeriodMode.month)return formatMonthYearPtBr(chartAnchor);
    final start=_chartStart;
    return '${formatShortMonthPtBr(start)} – ${'${formatShortMonthPtBr(chartAnchor)} ${chartAnchor.year}'}';
  }
  void _setChartMode(FinancePeriodMode next){setState((){chartMode=next;chartAnchor=next==FinancePeriodMode.week?_weekStart(DateTime.now()):_chartCurrentMonth;});}
  void _moveChart(int delta){setState((){
    if (chartMode == FinancePeriodMode.week) {
      chartAnchor = _chartStart.add(Duration(days: 7 * delta));
    } else if (chartMode == FinancePeriodMode.month) {
      chartAnchor = DateTime(chartAnchor.year, chartAnchor.month + delta, 1);
    } else {
      chartAnchor = DateTime(chartAnchor.year, chartAnchor.month + (delta * 6), 1);
    }
  });}

  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    final cur=_month(month);
    final incPaid=_sum(cur,income:true,paidOnly:true);
    final outPaid=_sum(cur,paidOnly:true);
    final pendingExpenses=cur.where((x)=>!x.income&&!x.isPaid&&!x.isCancelled).fold(0.0,(a,x)=>a+x.amount);
    final nextExpenses=items.where((x){
      if(x.income||x.isPaid||x.isCancelled)return false;
      final d=_date(x.dueDate);
      return d.isAfter(DateTime(month.year,month.month+1,0));
    }).fold(0.0,(a,x)=>a+x.amount);
    final projectedBalance=_balance()-pendingExpenses-nextExpenses;
    final cats=<String,double>{};
    for(final x in cur.where((x)=>!x.income)){cats[x.category]=(cats[x.category]??0)+x.amount;}
    return SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[
        Expanded(child:Text('Financeiro',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold))),
        FilledButton.icon(onPressed:_menu,icon:const Icon(Icons.add),label:const Text('Adicionar')),
      ]),
      const SizedBox(height:8),
      AppCard(child:Row(children:[
        IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month-1)),icon:const Icon(Icons.chevron_left)),
        Expanded(child:Text(formatMonthYearPtBr(month),textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold))),
        IconButton(onPressed:()=>setState(()=>month=DateTime(month.year,month.month+1)),icon:const Icon(Icons.chevron_right)),
      ])),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Saldo atual',style:Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:4),
        Text(money(_balance()),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:4),
        Text('Resultado disponível considerando apenas movimentações pagas.',style:Theme.of(context).textTheme.bodySmall),
      ])),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Resumo do mês',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        Row(children:[
          Expanded(child:_metricTile('Entradas recebidas',incPaid,Icons.arrow_downward)),
          const SizedBox(width:10),
          Expanded(child:_metricTile('Despesas pagas',outPaid,Icons.arrow_upward)),
        ]),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:_metricTile('Despesas pendentes',pendingExpenses,Icons.schedule)),
          const SizedBox(width:10),
          Expanded(child:_metricTile('Resultado do mês',incPaid-outPaid,Icons.account_balance_wallet_outlined)),
        ]),
      ])),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Próximas despesas',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:6),
        Text(nextExpenses==0?'Nenhuma próxima despesa registrada.':'Total previsto: ${money(nextExpenses)}'),
        const SizedBox(height:4),
        Text('Saldo previsto: ${money(projectedBalance)}',style:Theme.of(context).textTheme.bodySmall),
      ])),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Evolução financeira',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        SegmentedButton<FinancePeriodMode>(
          segments:const[
            ButtonSegment(value:FinancePeriodMode.week,label:Text('Semanal')),
            ButtonSegment(value:FinancePeriodMode.month,label:Text('Mensal')),
            ButtonSegment(value:FinancePeriodMode.semester,label:Text('Semestral')),
          ],
          selected:{chartMode},
          onSelectionChanged:(v){if(v.isNotEmpty)_setChartMode(v.first);},
        ),
        const SizedBox(height:8),
        Row(children:[
          IconButton(onPressed:()=>_moveChart(-1),icon:const Icon(Icons.chevron_left)),
          Expanded(child:Text(_chartLabel,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold))),
          if(_chartCanNext)IconButton(onPressed:()=>_moveChart(1),icon:const Icon(Icons.chevron_right))else const SizedBox(width:48),
        ]),
        const SizedBox(height:4),
        SizedBox(height:230,child:_FinanceInteractiveChart(start:_chartStart,end:_chartEnd,mode:chartMode,items:[...items],color:Theme.of(context).colorScheme.primary)),
      ])),
      if(cats.isNotEmpty)AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Despesas por categoria',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        for(final e in cats.entries)_category(e.key,e.value,cats.values.fold(0.0,(a,b)=>a+b)),
      ])),
      const SizedBox(height:8),
      Text('Últimas movimentações',style:Theme.of(context).textTheme.titleLarge),
      if(cur.isEmpty)const AppCard(child:Text('Nenhuma movimentação neste mês.')),
      for(final x in cur)_movement(x),
    ]));
  }


  Widget _metricTile(String label,double value,IconData icon)=>Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha:.45),borderRadius:BorderRadius.circular(14)),
    child:Row(children:[
      Icon(icon,size:20),
      const SizedBox(width:8),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(money(value),style:const TextStyle(fontWeight:FontWeight.bold)),
        Text(label,style:Theme.of(context).textTheme.bodySmall),
      ])),
    ]),
  );  Widget _category(String n,double v,double total)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(n),Text(money(v))]),LinearProgressIndicator(value:total==0?0:v/total)]));
  Widget _movement(MoneyTransaction x)=>AppCard(child:ListTile(contentPadding:EdgeInsets.zero,title:Text(x.description),subtitle:Text('${money(x.amount)} • Venc. ${DateFormat('dd/MM/yyyy').format(_date(x.dueDate))} • ${x.isPaid?'Pago':x.isOverdue?'Atrasado':'Previsto'}${x.isInstallment?' • Parcela ${x.installmentNumber}/${x.totalInstallments}':''}${x.isRecurring?' • Recorrente':''}'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='pay')_toggle(x);if(v=='edit')_edit(x);if(v=='delete')_remove(x);},itemBuilder:(_)=>const[PopupMenuItem(value:'pay',child:Text('Marcar pago/previsto')),PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir futuras'))])));

}

class _FinancePoint{
  final DateTime date;final double balance;final double delta;
  _FinancePoint(this.date,this.balance,this.delta);
}
// Gráficos reconstruídos: interação por toque e arraste.
class _FinanceInteractiveChart extends StatefulWidget{
  final DateTime start,end;final FinancePeriodMode mode;final List<MoneyTransaction> items;final Color color;
  const _FinanceInteractiveChart({required this.start,required this.end,required this.mode,required this.items,required this.color});
  @override State<_FinanceInteractiveChart> createState()=>_FinanceInteractiveChartState();
}
class _FinanceInteractiveChartState extends State<_FinanceInteractiveChart>{
  double? selectionX;
  @override Widget build(BuildContext context)=>GestureDetector(behavior:HitTestBehavior.opaque,onTapDown:(d)=>setState(()=>selectionX=d.localPosition.dx),onHorizontalDragUpdate:(d)=>setState(()=>selectionX=d.localPosition.dx),child:CustomPaint(painter:_FinanceChart(start:widget.start,end:widget.end,mode:widget.mode,items:widget.items,color:widget.color,selectedX:selectionX),child:const SizedBox.expand()));
}
class _FinanceChart extends CustomPainter{
  final DateTime start;final DateTime end;final FinancePeriodMode mode;final List<MoneyTransaction> items;final Color color;final double? selectedX;
  _FinanceChart({required this.start,required this.end,required this.mode,required this.items,required this.color,required this.selectedX});
  DateTime _movementDate(MoneyTransaction x)=>DateTime.tryParse(x.date)??DateTime(1900);
  double _delta(MoneyTransaction x)=>x.income?x.amount:-x.amount;

  @override void paint(Canvas c,Size s){
    if(!start.isBefore(end))return;
    final visibleEnd=end;
    if(!start.isBefore(visibleEnd))return;

    double opening=0;
    for(final x in items){
      if(x.isCancelled||!x.isPaid)continue;
      final d=_movementDate(x);
      if(d.isBefore(start))opening+=_delta(x);
    }

    final events=<DateTime,double>{};
    for(final x in items){
      if(x.isCancelled||!x.isPaid)continue;
      final d=_movementDate(x);
      if(d.isBefore(start)||!d.isBefore(visibleEnd))continue;
      final bucket=(mode==FinancePeriodMode.week||mode==FinancePeriodMode.month)?DateTime(d.year,d.month,d.day):DateTime(d.year,d.month,1);
      events[bucket]=(events[bucket]??0)+_delta(x);
    }

    final points=< _FinancePoint>[];
    var balance=opening;
    final buckets=events.keys.toList()..sort();
    for(final bucket in buckets){
      final delta=events[bucket]??0;
      if(delta.abs()<.000001)continue;
      balance+=delta;
      final pointDate=(mode==FinancePeriodMode.week||mode==FinancePeriodMode.month)?bucket:(
        DateTime(bucket.year,bucket.month+1,1).isAfter(visibleEnd)
          ?visibleEnd.subtract(const Duration(days:1))
          :DateTime(bucket.year,bucket.month+1,1).subtract(const Duration(days:1))
      );
      points.add(_FinancePoint(pointDate,balance,delta));
    }

    const left=52.0,right=16.0,top=26.0,bottom=40.0,edgeInset=10.0;
    final w=math.max(1.0,s.width-left-right).toDouble();
    final h=math.max(1.0,s.height-top-bottom).toDouble();
    final innerW=math.max(1.0,w-edgeInset*2).toDouble();
    double? nextBalance;
    final futureEvents=<DateTime,double>{};
    for(final x in items){
      if(x.isCancelled||!x.isPaid)continue;
      final d=_movementDate(x);
      if(d.isBefore(visibleEnd))continue;
      final bucket=DateTime(d.year,d.month,d.day);
      futureEvents[bucket]=(futureEvents[bucket]??0)+_delta(x);
    }
    if(futureEvents.isNotEmpty){
      final firstFuture=futureEvents.keys.toList()..sort();
      final delta=futureEvents[firstFuture.first]??0;
      var futureOpening=opening+events.values.fold(0.0,(a,b)=>a+b);
      nextBalance=futureOpening+delta;
    }

    final scaleValues=<double>[opening,...points.map((p)=>p.balance),if(nextBalance!=null)nextBalance];
    var minV=scaleValues.reduce((a,b)=>math.min(a,b).toDouble());
    var maxV=scaleValues.reduce((a,b)=>math.max(a,b).toDouble());
    if((maxV-minV).abs()<.01){minV-=1;maxV+=1;}
    final range=maxV-minV;
    final grid=Paint()..color=color.withValues(alpha:.14)..strokeWidth=1;
    final vertical=Paint()..color=color.withValues(alpha:.08)..strokeWidth=1;
    final axis=Paint()..color=color.withValues(alpha:.35)..strokeWidth=1;
    final line=Paint()..color=color..strokeWidth=3..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    final totalDays=math.max(1,visibleEnd.difference(start).inDays).toDouble();
    double xFor(DateTime d){
      final span=totalDays-1;
      final days=d.difference(start).inDays.toDouble();
      return left+edgeInset+innerW*(span<=0?0.5:days/span);
    }
    double yFor(double value)=>top+h-(value-minV)/range*h;

    for(var row=0;row<=4;row++){
      final y=top+h*row/4;
      c.drawLine(Offset(left,y),Offset(s.width-right,y),grid);
      _text(c,moneyLabel(maxV-range*row/4),Offset(2,y-7),9,color.withValues(alpha:.75));
    }

    if(mode==FinancePeriodMode.week||mode==FinancePeriodMode.month){
      final days=visibleEnd.difference(start).inDays;
      for(var i=0;i<days;i++){
        final d=start.add(Duration(days:i));final x=xFor(d);
        c.drawLine(Offset(x,top),Offset(x,s.height-bottom),vertical);
        final showLabel=days<=10||i==0||i==days-1||(i%5==0);
        if(showLabel)_text(c,DateFormat('dd/MM').format(d),Offset(x-14,s.height-bottom+8),9,color.withValues(alpha:.75));
      }
    }else{
      for(var d=DateTime(start.year,start.month,1);d.isBefore(visibleEnd);d=DateTime(d.year,d.month+1,1)){
        final x=xFor(d);
        c.drawLine(Offset(x,top),Offset(x,s.height-bottom),vertical);
        _text(c,formatShortMonthPtBr(d),Offset(x-16,s.height-bottom+8),9,color.withValues(alpha:.75));
      }
    }

    final segments=<List<Offset>>[];
    if(points.isNotEmpty){
      segments.add([Offset(left,yFor(opening)),Offset(xFor(points.first.date),yFor(points.first.balance))]);
      for(var i=1;i<points.length;i++) {
        segments.add([Offset(xFor(points[i-1].date),yFor(points[i-1].balance)),Offset(xFor(points[i].date),yFor(points[i].balance))]);
      }
      if(nextBalance!=null)segments.add([Offset(xFor(points.last.date),yFor(points.last.balance)),Offset(left+w-edgeInset,yFor(nextBalance))]);
      final path=Path();
      for(final seg in segments){path.moveTo(seg[0].dx,seg[0].dy);path.lineTo(seg[1].dx,seg[1].dy);}
      c.drawPath(path,line);
      int? selected;
      if(selectedX!=null){
        selected=0;var best=(xFor(points.first.date)-selectedX!).abs();
        for(var i=0;i<points.length;i++){final d=(xFor(points[i].date)-selectedX!).abs();if(d<best){best=d;selected=i;}}
      }
      final values=points.map((p)=>p.balance).toList();
      final minIndex=_indexOfMin(values),maxIndex=_indexOfMax(values);
      final labelIndices=<int>{minIndex,maxIndex};
      if(selected!=null)labelIndices.add(selected);
      final occupied=<Rect>[];
      for(final i in labelIndices.toList()..sort()){
        final p=points[i];
        final point=Offset(xFor(p.date),yFor(p.balance));
        final label='${DateFormat('dd/MM/yyyy').format(p.date)}\n${moneyPoint(p.balance)}';
        _drawLabel(c,s,point,label,segments,occupied,top,bottom);
        c.drawCircle(point,i==selected?9:4,Paint()..color=color);
      }
      for(var i=0;i<points.length;i++){
        if(labelIndices.contains(i))continue;
        final p=points[i];
        c.drawCircle(Offset(xFor(p.date),yFor(p.balance)),i==selected?9:4,Paint()..color=color);
      }
    }
    if(points.isEmpty){_text(c,'Nada registrado',Offset(s.width/2,s.height/2-10),14,color);}
    c.drawLine(Offset(left,top),Offset(left,s.height-bottom),axis);
    c.drawLine(Offset(left,s.height-bottom),Offset(s.width-right,s.height-bottom),axis);
  }

  int _indexOfMin(List<double> values){var index=0;for(var i=1;i<values.length;i++) {
    if(values[i]<values[index])index=i;
  }return index;}
  int _indexOfMax(List<double> values){var index=0;for(var i=1;i<values.length;i++) {
    if(values[i]>values[index])index=i;
  }return index;}
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
      text:TextSpan(text:label,style:TextStyle(fontSize:10,color:color,fontWeight:FontWeight.w600)),
      textDirection:ui.TextDirection.ltr,
      textAlign:TextAlign.center,
    )..layout(maxWidth:92);
    const pad=3.0;
    final bounds=Rect.fromLTRB(2,2,s.width-2,s.height-bottom-2);
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
    Offset? chosen;Rect? chosenRect;
    for(final pos in candidates){
      final rect=Rect.fromLTWH(pos.dx-pad,pos.dy-pad,tp.width+pad*2,tp.height+pad*2);
      if(rect.left<bounds.left||rect.top<bounds.top||rect.right>bounds.right||rect.bottom>bounds.bottom)continue;
      if(occupied.any((r)=>r.overlaps(rect)))continue;
      if(_lineHitsRect(segments,rect))continue;
      chosen=pos;chosenRect=rect;break;
    }
    if(chosen==null){
      var bestScore=double.infinity;
      for(final pos in candidates){
        final rect=Rect.fromLTWH(pos.dx-pad,pos.dy-pad,tp.width+pad*2,tp.height+pad*2);
        if(rect.left<bounds.left||rect.top<bounds.top||rect.right>bounds.right||rect.bottom>bounds.bottom)continue;
        if(occupied.any((r)=>r.overlaps(rect)))continue;
        var score=0.0;
        for(final seg in segments){
          final mid=Offset((seg[0].dx+seg[1].dx)/2,(seg[0].dy+seg[1].dy)/2);
          score+=1/(1+math.sqrt(math.pow(mid.dx-rect.center.dx,2)+math.pow(mid.dy-rect.center.dy,2)));
        }
        if(score<bestScore){bestScore=score;chosen=pos;chosenRect=rect;}
      }
    }
    if(chosen==null){
      final fallbackX=(point.dx-tp.width/2).clamp(bounds.left+pad,bounds.right-tp.width-pad).toDouble();
      final fallbackY=(point.dy+7).clamp(bounds.top+pad,bounds.bottom-tp.height-pad).toDouble();
      chosen=Offset(fallbackX,fallbackY);
      chosenRect=Rect.fromLTWH(chosen.dx-pad,chosen.dy-pad,tp.width+pad*2,tp.height+pad*2);
    }
    occupied.add(chosenRect!);
    final edge=Offset(point.dx.clamp(chosenRect.left,chosenRect.right).toDouble(),point.dy.clamp(chosenRect.top,chosenRect.bottom).toDouble());
    c.drawLine(point,edge,Paint()..color=color.withValues(alpha:.35)..strokeWidth=1);
    tp.paint(c,chosen);
  }
  String deltaLabel(double value){
    final sign=value>=0?'+':'-';
    return 'R\$$sign${value.abs().toStringAsFixed(2).replaceAll('.',',')}';
  }
  String moneyPoint(double value)=>'R\$${value.toStringAsFixed(value.truncateToDouble()==value?0:2).replaceAll('.',',')}';
  String moneyLabel(double value){
    final sign=value<0?'-':'';
    final abs=value.abs();
    if(abs>=1000)return 'R\$$sign${(abs/1000).toStringAsFixed(abs%1000==0?0:1)}k';
    return 'R\$$sign${abs.toStringAsFixed(abs.truncateToDouble()==abs?0:2).replaceAll('.',',')}';
  }
  void _text(Canvas c,String text,Offset position,double size,Color textColor){
    final tp=TextPainter(text:TextSpan(text:text,style:TextStyle(fontSize:size,color:textColor,fontWeight:FontWeight.w500)),textDirection:ui.TextDirection.ltr)..layout(maxWidth:88);
    tp.paint(c,position);
  }
  @override bool shouldRepaint(covariant _FinanceChart old)=>old.start!=start||old.end!=end||old.mode!=mode||old.items!=items||old.color!=color||old.selectedX!=selectedX;
}