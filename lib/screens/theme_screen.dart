import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../widgets/app_card.dart';

class ThemeEditResult {
  final ThemeSettings settings;
  final ThemeMode mode;
  ThemeEditResult(this.settings, this.mode);
}

class ThemeScreen extends StatefulWidget {
  final ThemeSettings initialSettings;
  final ThemeMode initialMode;
  const ThemeScreen({super.key, required this.initialSettings, required this.initialMode});
  @override State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  late ThemeSettings settings;
  late ThemeMode mode;
  static const colors = <Color>[
    Color(0xFFF7F5FA), Color(0xFFE8F5E9), Color(0xFFE3F2FD), Color(0xFFFFF3E0),
    Color(0xFFFCE4EC), Color(0xFFEDE7F6), Color(0xFFE0F2F1), Color(0xFFFFFDE7),
    Color(0xFF263238), Color(0xFF37474F), Color(0xFF3F51B5), Color(0xFF00695C),
    Color(0xFFE91E63), Color(0xFF2196F3), Color(0xFF00A884), Color(0xFFFF9800),
    Color(0xFF9C27B0), Color(0xFF795548),
  ];
  @override void initState(){super.initState();settings=widget.initialSettings;mode=widget.initialMode;}

  Future<void> _save(ThemeSettings next) async { setState(() => settings=next); await ThemeService.save(next); }
  Future<void> _mode(ThemeMode m) async { final p=await SharedPreferences.getInstance(); await p.setString('theme_mode',m==ThemeMode.dark?'dark':m==ThemeMode.light?'light':'system'); if(mounted)setState(()=>mode=m); }
  Future<void> _pickImage() async { final p=await ThemeService.pickAndPersistImage(); if(p!=null&&mounted)await _save(settings.copyWith(imagePath:p)); }
  Future<void> _clearImage() async => _save(settings.copyWith(clearImagePath:true));

  Future<void> _pickColor(String title, Color current, Future<void> Function(Color) onChanged) async {
    var value=current;
    final hexController=TextEditingController(text:value.value.toRadixString(16).padLeft(8,'0').substring(2).toUpperCase());
    final result=await showDialog<Color>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,setDialog)=>AlertDialog(
      title:Text(title),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:double.infinity,height:64,decoration:BoxDecoration(color:value,borderRadius:BorderRadius.circular(16),border:Border.all(color:Theme.of(context).colorScheme.outline))),
        const SizedBox(height:12),
        TextField(controller:hexController,decoration:const InputDecoration(labelText:'Cor HEX',prefixText:'#'),onChanged:(text){
          final raw=text.replaceAll('#','').trim(); final parsed=int.tryParse(raw.length==6?'FF$raw':raw,radix:16);
          if(parsed!=null&&raw.length==6)setDialog(()=>value=Color(parsed));
        }),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:colors.map((c)=>InkWell(onTap:(){setDialog(()=>value=c);hexController.text=c.value.toRadixString(16).padLeft(8,'0').substring(2).toUpperCase();},child:Container(width:34,height:34,decoration:BoxDecoration(color:c,shape:BoxShape.circle,border:Border.all(color:value.value==c.value?Theme.of(context).colorScheme.primary:Colors.black26,width:value.value==c.value?3:1))))).toList()),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,value),child:const Text('Aplicar'))],
    )));
    hexController.dispose();
    if(result!=null)await onChanged(result);
  }

  Color _resolveCardColor(BuildContext context)=>settings.cardColorValue==0?(Theme.of(context).brightness==Brightness.dark?const Color(0xFF1F1F24):Colors.white):Color(settings.cardColorValue);
  Color _resolveNavColor(BuildContext context)=>settings.navColorValue==0?Theme.of(context).colorScheme.surface:Color(settings.navColorValue);
  Color _contrast(Color background)=>background.computeLuminance()>.48?Colors.black87:Colors.white;

  Widget _colorRow(String title,Color color,VoidCallback onTap)=>ListTile(
    contentPadding:EdgeInsets.zero,
    leading:Container(width:42,height:42,decoration:BoxDecoration(color:color,shape:BoxShape.circle,border:Border.all(color:Theme.of(context).colorScheme.outline))),
    title:Text(title),
    subtitle:Text('#${color.value.toRadixString(16).padLeft(8,'0').substring(2).toUpperCase()}'),
    trailing:const Icon(Icons.chevron_right),
    onTap:onTap,
  );

  @override Widget build(BuildContext context){
    final has=settings.imagePath!=null; final card=_resolveCardColor(context); final nav=_resolveNavColor(context);
    return Scaffold(appBar:AppBar(title:const Text('Personalizar tema'),leading:IconButton(icon:const Icon(Icons.close),onPressed:()=>Navigator.pop(context,ThemeEditResult(settings,mode)))),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Text('Modo do aplicativo',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),
        SegmentedButton<ThemeMode>(segments:const[
          ButtonSegment(value:ThemeMode.system,label:Text('Sistema'),icon:Icon(Icons.settings_brightness_outlined)),
          ButtonSegment(value:ThemeMode.light,label:Text('Claro'),icon:Icon(Icons.light_mode_outlined)),
          ButtonSegment(value:ThemeMode.dark,label:Text('Escuro'),icon:Icon(Icons.dark_mode_outlined))],
          selected:{mode},onSelectionChanged:(s)=>_mode(s.first)),
        const SizedBox(height:24),
        Text('Cores dos elementos',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),
        _colorRow('Cards — preenchimento',card,()=>_pickColor('Cor do preenchimento dos cards',card,(c)=>_save(settings.copyWith(cardColorValue:c.value)))),
        _slider('Transparência do preenchimento',settings.cardOpacity,.05,1,(v)=>settings.copyWith(cardOpacity:v)),
        _colorRow('Cards — contorno',Color(settings.cardBorderColorValue),()=>_pickColor('Cor do contorno dos cards',Color(settings.cardBorderColorValue),(c)=>_save(settings.copyWith(cardBorderColorValue:c.value)))),
        _slider('Visibilidade do contorno',1,1,1,(v)=>settings),
        _colorRow('Barra de navegação',nav,()=>_pickColor('Cor da barra de navegação',nav,(c)=>_save(settings.copyWith(navColorValue:c.value)))),
        _slider('Transparência da barra',settings.navOpacity,.05,1,(v)=>settings.copyWith(navOpacity:v)),
        _colorRow('Elementos de destaque',Color(settings.accentColorValue),()=>_pickColor('Cor dos elementos de destaque',Color(settings.accentColorValue),(c)=>_save(settings.copyWith(accentColorValue:c.value)))),
        const SizedBox(height:12),
        AppCardPreview(card:card,cardOpacity:settings.cardOpacity,border:Color(settings.cardBorderColorValue),nav:nav,navOpacity:settings.navOpacity,contrast:_contrast),
        const SizedBox(height:8),
        const Card(child:ListTile(leading:Icon(Icons.contrast_outlined),title:Text('Contraste'),subtitle:Text('Texto e ícones principais mantêm contraste automático.'))),
        const SizedBox(height:20),
        Text('Cor de fundo',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),
        Wrap(spacing:12,runSpacing:12,children:colors.map((c){final selected=!has&&settings.backgroundColorValue==c.value;return InkWell(onTap:()=>_save(settings.copyWith(backgroundColorValue:c.value,clearImagePath:true)),borderRadius:BorderRadius.circular(18),child:AnimatedContainer(duration:const Duration(milliseconds:150),width:52,height:52,decoration:BoxDecoration(color:c,borderRadius:BorderRadius.circular(18),border:Border.all(color:selected?Theme.of(context).colorScheme.primary:Colors.black12,width:selected?3:1)),child:selected?Icon(Icons.check,color:c.computeLuminance()>.55?Colors.black:Colors.white):null));}).toList()),
        const SizedBox(height:28),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Foto personalizada',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),
          Text(has?'Sua foto está aplicada ao fundo.':'Escolha uma foto da galeria para usar como fundo.'),const SizedBox(height:12),
          FilledButton.icon(onPressed:_pickImage,icon:const Icon(Icons.photo_library_outlined),label:Text(has?'Trocar foto':'Usar minha foto')),
          if(has)...[TextButton.icon(onPressed:_clearImage,icon:const Icon(Icons.close),label:const Text('Remover foto')),_slider('Zoom',settings.scale,.5,3,(v)=>settings.copyWith(scale:v)),_slider('Posição horizontal',settings.x,-5,5,(v)=>settings.copyWith(x:v)),_slider('Posição vertical',settings.y,-5,5,(v)=>settings.copyWith(y:v)),_slider('Transparência da foto',settings.opacity,.05,1,(v)=>settings.copyWith(opacity:v))]
        ]))),
        const SizedBox(height:12),
        const Card(child:ListTile(leading:Icon(Icons.info_outline),title:Text('Tema salvo automaticamente'),subtitle:Text('As configurações permanecem após fechar e abrir o Polirotinas.')))
      ]);
  }

  Widget _slider(String label,double value,double min,double max,ThemeSettings Function(double) next)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(label),Text('${(value*100).round()}%')]),
    Slider(value:value,min:min,max:max,divisions:20,onChanged:(v)=>_save(next(v)))
  ]);
}

class AppCardPreview extends StatelessWidget {
  final Color card;final double cardOpacity;final Color border;final Color nav;final double navOpacity;final Color Function(Color) contrast;
  const AppCardPreview({super.key,required this.card,required this.cardOpacity,required this.border,required this.nav,required this.navOpacity,required this.contrast});
  @override Widget build(BuildContext context)=>Column(children:[
    Align(alignment:Alignment.centerLeft,child:Text('Pré-visualização',style:Theme.of(context).textTheme.titleMedium)),const SizedBox(height:8),
    Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:card.withValues(alpha:cardOpacity),borderRadius:BorderRadius.circular(20),border:Border.all(color:border)),child:Text('Card de exemplo',style:TextStyle(color:contrast(card.withValues(alpha:cardOpacity)),fontWeight:FontWeight.bold))),
    const SizedBox(height:8),
    Container(height:54,decoration:BoxDecoration(color:nav.withValues(alpha:navOpacity),borderRadius:BorderRadius.circular(18)),child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[for(final icon in [Icons.calendar_month,Icons.fitness_center,Icons.home,Icons.restaurant,Icons.account_balance_wallet])Icon(icon,color:contrast(nav.withValues(alpha:navOpacity)))]))
  ]);
}
