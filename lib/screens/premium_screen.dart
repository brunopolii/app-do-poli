import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  final VoidCallback onActivate;

  const PremiumScreen({super.key, required this.onActivate});

  static const Color _accent = Color(0xFF9B82DB);

  static const List<String> _benefits = [
    'Agenda com compromissos ilimitados',
    'Criação e registro de treinos sem limites',
    'Registros de alimentação ilimitados',
    'Lançamentos financeiros ilimitados',
    'Diário completo com anotações ilimitadas',
    'Histórico completo e gráficos de evolução',
    'Acesso a todos os períodos dos gráficos, incluindo evolução do peso',
    'Todas as opções de personalização, incluindo imagem de fundo',
    'Acesso a todos os recursos Premium enquanto a licença estiver válida',
  ];

  void _checkoutUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('O pagamento online estará disponível assim que os links de checkout forem configurados.'),
      ),
    );
  }

  Widget _planCard({
    required BuildContext context,
    required String name,
    required String price,
    required String description,
    required IconData icon,
    bool featured = false,
  }) {
    final color = Theme.of(context).colorScheme;
    return Card(
      elevation: featured ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: featured ? _accent : color.outlineVariant,
          width: featured ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: _accent, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              if (featured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(30)),
                  child: const Text('MAIS COMPLETO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 12),
            Text(price, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _checkoutUnavailable(context),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Comprar — em breve'),
                style: FilledButton.styleFrom(
                  backgroundColor: featured ? _accent : null,
                  foregroundColor: featured ? Colors.black : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Poliroutines Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accent.withValues(alpha: .24), theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 42, color: _accent),
                  const SizedBox(height: 12),
                  Text('Seu planejamento, sem limites', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Desbloqueie todos os recursos do Poliroutines e acompanhe sua evolução sem restrições.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Tudo o que você ganha', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._benefits.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: _accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(benefit, style: theme.textTheme.bodyLarge)),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Text('Escolha seu plano', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _planCard(context: context, name: 'Mensal', price: 'R\$ 9,90', description: 'Primeira parcela R\$ 9,90; depois R\$ 11,90 por mês.', icon: Icons.calendar_month_outlined),
            _planCard(context: context, name: 'Anual', price: 'R\$ 59,90', description: 'Pagamento anual.', icon: Icons.event_available_outlined, featured: true),
            _planCard(context: context, name: 'Vitalício', price: 'R\$ 99,90', description: 'Pagamento único. Sem vencimento.', icon: Icons.all_inclusive_rounded),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onActivate,
              icon: const Icon(Icons.key_outlined),
              label: const Text('Já tenho uma chave de ativação'),
            ),
            const SizedBox(height: 8),
            Text('Os botões de compra serão ativados quando os links oficiais de pagamento estiverem configurados. Nenhuma compra é realizada nesta versão.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
