import 'package:flutter/material.dart';

import '../services/experimental_metrics_service.dart';
import '../services/plan_service.dart';
import 'activation_screen.dart';

class PremiumScreen extends StatefulWidget {
  final VoidCallback onActivated;
  const PremiumScreen({super.key, required this.onActivated});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _premium = false;
  bool _loading = true;
  String _selectedPlan = 'Anual';
  final _metrics = ExperimentalMetricsService();

  @override
  void initState() {
    super.initState();
    _metrics.record('premium_screen_view');
    _refresh();
  }

  Future<void> _refresh() async {
    final active = await PlanService().hasPremium;
    if (mounted) setState(() { _premium = active; _loading = false; });
  }

  void _openActivation() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ActivationScreen(onActivated: () {
        widget.onActivated();
        Navigator.of(context).pop();
        _refresh();
      }),
    ));
  }

  Future<void> _selectPlan(String plan) async {
    setState(() => _selectedPlan = plan);
    await _metrics.record('plan_selected', details: {'plan': plan});
  }

  Future<void> _purchaseIntent() async {
    await _metrics.record('purchase_intent', details: {'plan': _selectedPlan});
    if (!mounted) return;
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Compra em modo de teste'),
      content: Text('Plano selecionado: ' + _selectedPlan + '. O checkout oficial ainda não está conectado, então nenhuma cobrança será feita.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Entendi'))],
    ));
  }

  Future<void> _showMetrics() async {
    final data = await _metrics.summary();
    if (!mounted) return;
    const labels = <String, String>{
      'install_first_open': 'Primeira abertura neste aparelho',
      'premium_screen_view': 'Visualizações da tela Premium',
      'plan_selected': 'Seleções de plano',
      'purchase_intent': 'Intenções de compra (teste)',
      'license_activation_success': 'Ativações bem-sucedidas',
      'license_activation_failure': 'Falhas de ativação',
    };
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Métricas experimentais'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: labels.entries.map((entry) => ListTile(
        dense: true, contentPadding: EdgeInsets.zero, title: Text(entry.value),
        trailing: Text((data[entry.key] ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
      )).toList())),
      actions: [
        TextButton(onPressed: () async { await _metrics.clear(); if (dialogContext.mounted) Navigator.pop(dialogContext); }, child: const Text('Zerar dados de teste')),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar')),
      ],
    ));
  }

  Widget _benefit(IconData icon, String title, String description) => ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(description),
  );

  Widget _planCard({required String title, required String price, required String detail, required String value}) {
    final selected = _selectedPlan == value;
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 2 : 1)),
      child: InkWell(borderRadius: BorderRadius.circular(18), onTap: () => _selectPlan(value), child: Padding(
        padding: const EdgeInsets.all(16), child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? colors.primary : colors.outline),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4), Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ])),
          const SizedBox(width: 8), Text(price, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Poliroutines Premium'), actions: [IconButton(tooltip: 'Métricas do teste', onPressed: _showMetrics, icon: const Icon(Icons.analytics_outlined))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [colors.primaryContainer, colors.surfaceContainerHighest], begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.workspace_premium_rounded, size: 44, color: colors.primary), const SizedBox(height: 12),
          Text(_premium ? 'Seu Premium está ativo' : 'Sua rotina, sem limites', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), Text(_premium ? 'Sua licença está ativa. Aproveite todos os recursos Premium neste aparelho.' : 'Treine com consistência, organize sua vida e acompanhe sua evolução em um só lugar.'),
          if (!_premium) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: _purchaseIntent, icon: const Icon(Icons.lock_open_rounded), label: const Text('Conhecer opções de Premium'))],
        ])),
        const SizedBox(height: 20), Text('Veja o que você desbloqueia', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6),
        _benefit(Icons.event_available_outlined, 'Agenda mais flexível', 'Mais registros para compromissos e rotina.'),
        _benefit(Icons.fitness_center_outlined, 'Treinos e evolução', 'Mais planos, histórico e acompanhamento dos treinos.'),
        _benefit(Icons.restaurant_outlined, 'Alimentação e corpo', 'Histórico ampliado para observar seus hábitos.'),
        _benefit(Icons.account_balance_wallet_outlined, 'Controle financeiro', 'Mais registros para entradas e despesas.'),
        _benefit(Icons.menu_book_outlined, 'Diário completo', 'Histórico e ferramentas extras para suas anotações.'),
        _benefit(Icons.insights_outlined, 'Gráficos e personalização', 'Acompanhe evolução e personalize a aparência.'),
        if (!_premium) ...[
          const SizedBox(height: 18), Text('Compare os planos', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            const Row(children: [Expanded(child: Text('Recurso', style: TextStyle(fontWeight: FontWeight.bold))), SizedBox(width: 66, child: Text('Grátis', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))), SizedBox(width: 76, child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))]),
            const Divider(),
            ...[('Agenda', 'Até 5', 'Ilimitada'), ('Planos de treino', '1 plano', 'Ilimitados'), ('Alimentação', 'Limite mensal', 'Ampliada'), ('Finanças', 'Limite mensal', 'Ampliadas'), ('Diário', '1 anotação/dia', 'Diário completo'), ('Gráficos e temas', 'Básico', 'Completo')].map((row) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text(row.$1)), SizedBox(width: 66, child: Text(row.$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)), SizedBox(width: 76, child: Text(row.$3, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)))]))),
          ]))),
          const SizedBox(height: 18), Text('Escolha seu plano', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6),
          _planCard(title: 'Mensal', price: 'R\$ 9,90', detail: 'Primeira cobrança; depois R\$ 11,90/mês', value: 'Mensal'),
          _planCard(title: 'Anual', price: 'R\$ 59,90', detail: 'Acesso Premium por 12 meses', value: 'Anual'),
          _planCard(title: 'Vitalício', price: 'R\$ 99,90', detail: 'Pagamento único, sem vencimento', value: 'Vitalício'),
          const SizedBox(height: 10), FilledButton.icon(onPressed: _purchaseIntent, icon: const Icon(Icons.shopping_cart_checkout), label: Text('Continuar com ' + _selectedPlan)),
          const SizedBox(height: 8), Text('MODO DE TESTE: a seleção e a intenção de compra são registradas somente neste aparelho. O checkout ainda não está conectado; nenhuma cobrança será feita.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 12), OutlinedButton.icon(onPressed: _openActivation, icon: const Icon(Icons.key_rounded), label: const Text('Já tenho uma licença — ativar')),
        ] else FilledButton.icon(onPressed: _openActivation, icon: const Icon(Icons.sync_rounded), label: const Text('Reativar / restaurar licença')),
      ]),
    );
  }
}
