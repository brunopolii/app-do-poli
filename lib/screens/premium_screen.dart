import 'package:flutter/material.dart';

import 'activation_screen.dart';
import '../services/plan_service.dart';

class PremiumScreen extends StatefulWidget {
  final VoidCallback onActivated;
  const PremiumScreen({super.key, required this.onActivated});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _premium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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

  Widget _planCard({
    required String title,
    required String price,
    required String detail,
    required IconData icon,
    bool highlighted = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: highlighted ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: highlighted ? colors.primary : colors.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
            const SizedBox(width: 8),
            Text(price, textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Poliroutines Premium')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.surfaceContainerHighest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 44, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(_premium ? 'Seu Premium está ativo' : 'Desbloqueie seu potencial', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_premium
                          ? 'Sua licença está ativa. Todos os recursos Premium estão liberados neste aparelho.'
                          : 'Tenha mais liberdade para organizar sua rotina, acompanhar sua evolução e personalizar o aplicativo.'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('O que está incluído', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const _Benefit(icon: Icons.event_available_outlined, text: 'Agenda com registros ilimitados'),
                const _Benefit(icon: Icons.fitness_center_outlined, text: 'Planos e histórico de treinos sem limites'),
                const _Benefit(icon: Icons.restaurant_outlined, text: 'Alimentação e acompanhamento corporal completos'),
                const _Benefit(icon: Icons.account_balance_wallet_outlined, text: 'Registros financeiros sem limite mensal'),
                const _Benefit(icon: Icons.menu_book_outlined, text: 'Diário completo, com histórico, categorias, humor e favoritos'),
                const _Benefit(icon: Icons.insights_outlined, text: 'Gráficos e histórico de evolução completos'),
                const _Benefit(icon: Icons.wallpaper_outlined, text: 'Personalização com foto de fundo'),
                const SizedBox(height: 20),
                if (!_premium) ...[
                  Text('Escolha seu plano', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _planCard(title: 'Mensal', price: 'R\$ 9,90', detail: 'Primeira parcela; depois R\$ 11,90/mês', icon: Icons.calendar_month_outlined),
                  _planCard(title: 'Anual', price: 'R\$ 59,90', detail: 'Acesso Premium por 12 meses', icon: Icons.date_range_outlined),
                  _planCard(title: 'Vitalício', price: 'R\$ 99,90', detail: 'Pagamento único, sem vencimento', icon: Icons.workspace_premium_outlined, highlighted: true),
                  const SizedBox(height: 8),
                  Text('A compra ainda deve ser concluída no canal oficial de venda. Os botões de checkout serão conectados quando os links oficiais estiverem configurados.', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openActivation,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Já tenho uma licença — ativar'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _openActivation,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Reativar / restaurar licença'),
                  ),
              ],
            ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Benefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Text(text)),
    ]),
  );
}
