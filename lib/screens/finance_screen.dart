import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../widgets/app_card.dart';

const expenseCategories = ['Alimentação','Transporte','Moradia','Lazer','Educação','Saúde','Compras','Outros'];
const incomeCategories = ['Salário','Freelance','Investimentos','Outros'];

class FinanceScreen extends StatefulWidget { const FinanceScreen({super.key}); @override State<FinanceScreen> createState()=>_FinanceScreenState(); }
class _FinanceScreenState extends State<FinanceScreen> {
  List<MoneyTransaction> tx=[]; DateTime month=DateTime(DateTime.now().year,DateTime.now().month);
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { tx=(await StorageService.read('finance')).map(MoneyTransaction.fromJson).toList(); if(mounted)setState((){}); }
  Future<void> _save() => StorageService.write('finance',tx.map((e)=>e.toJson()).toList());
  bool _sameMonth(MoneyTransaction x)=>x.date.startsWith(DateFormat('yyyy-MM').format(month));
  double _sum(Iterable<MoneyTransaction> list)=>list.fold(0.0,(s,x)=>s+x.amount);
  void _month(int delta)=>setState(()=>month=DateTime(month.year,month.month+delta));

  Future<void> _edit({MoneyTransaction? old}) async {
    final d=TextEditingController(text:old?.description??'');
    final a=TextEditingController(text:old==null?'':old.amount.toString());
    bool income=old?.income??false; String category=old?.category??'Outros';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,ss){
      final cats=income?incomeCategories:expenseCategories;
      if(!cats.contains(category)) category='Outros';
      return AlertDialog(title:Text(old==null?'Nova movimentação':'Editar movimentação'),content:SingleChildScrollView(child:Column(children:[
        TextField(controller:d,decoration:const InputDecoration(labelText:'Descrição',prefixIcon:Icon(Icons.notes_outlined))),
        TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Valor',prefixText:'R$ ')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:income,title:const Text('Entrada de dinheiro'),onChanged:(v)=>ss(()=>income=v)),
        DropdownButtonFormField<String>(initialValue:category,items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)ss(()=>category=v);},decoration:const InputDecoration(labelText:'Categoria'))
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Salvar'))]);
    }));
    final value=double.tryParse(a.text.replaceAll(',','.'));
    if(ok!=true||d.text.trim().isEmpty||value==null||value<=0)return;
    final item=MoneyTransaction(id:old?.id??DateTime.now().microsecondsSinceEpoch.toString(),date:old?.date??DateFormat('yyyy-MM-dd').format(DateTime.now()),description:d.text.trim(),category:category,amount:value,income:income);
    tx.removeWhere((x)=>x.id==item.id);tx.add(item);await _save();if(mounted)setState((){});
  }
  Future<void> _delete(MoneyTransaction x)async{tx.removeWhere((e)=>e.id==x.id);await _save();if(mounted)setState((){});}

  @override Widget build(BuildContext context){
    final current=tx.where(_sameMonth).toList()..sort((a,b)=>b.date.compareTo(a.date));
    final income=_sum(current.where((x)=>x.income)); final expense=_sum(current.where((x)=>!x.income)); final result=income-expense;
    final balance=_sum(tx.where((x)=>x.income))-_sum(tx.where((x)=>!x.income));
    final cats=<String,double>{}; for(final x in current.where((x)=>!x.income)){cats[x.category]=(cats[x.category]??0)+x.amount;}
    final maxCat=cats.values.isEmpty?1.0:cats.values.reduce((a,b)=>a>b?a:b);
    return SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(16,14,16,28),children:[
      Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Financeiro',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),Text('${current.length} movimentações no mês')])),IconButton.filled(onPressed:()=>_edit(),icon:const Icon(Icons.add))]),
      const SizedBox(height:10),
      AppCard(child:Row(children:[IconButton(onPressed:()=>_month(-1),icon:const Icon(Icons.chevron_left)),Expanded(child:Text(DateFormat('MMMM yyyy','pt_BR').format(month),textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),IconButton(onPressed:()=>_month(1),icon:const Icon(Icons.chevron_right))])),
      Row(children:[_metric('Entradas',income,Icons.arrow_downward),_metric('Despesas',expense,Icons.arrow_upward),_metric('Resultado',result,Icons.account_balance_wallet_outlined)]),
      AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Resumo',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:12),_bar('Entradas',income,income+expense),_bar('Despesas',expense,income+expense),const SizedBox(height:6),Text('Saldo acumulado: R$ ${balance.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.w600))])),
      if(cats.isNotEmpty) AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Despesas por categoria',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),const SizedBox(height:12),...cats.entries.map((e)=>_bar(e.key,e.value,maxCat))])),
      Row(children:[Expanded(child:Text('Movimentações',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),Text('${current.length}')]),const SizedBox(height:8),
      if(current.isEmpty)const AppCard(child:Text('Nenhuma movimentação neste mês.')),
      ...current.map((x)=>AppCard(child:ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Icon(x.income?Icons.south_west:Icons.north_east)),title:Text(x.description,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text('${x.category} • ${DateFormat('dd/MM').format(DateTime.parse(x.date))}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${x.income?'+':'-'} R$ ${x.amount.toStringAsFixed(2)}'),PopupMenuButton<String>(onSelected:(v){if(v=='edit')_edit(old:x);if(v=='delete')_delete(x);},itemBuilder:(c)=>const[PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Excluir'))])]))))
    ]));
  }
  Widget _metric(String label,double value,IconData icon)=>Expanded(child:AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon),const SizedBox(height:5),Text('R$ ${value.toStringAsFixed(0)}',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),Text(label,style:Theme.of(context).textTheme.bodySmall)])));
  Widget _bar(String label,double value,double total){final p=total<=0?0.0:(value/total).clamp(0.0,1.0).toDouble();return Padding(padding:const EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(label)),Text('R$ ${value.toStringAsFixed(2)}')]),const SizedBox(height:4),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:p,minHeight:8))]));}
}
