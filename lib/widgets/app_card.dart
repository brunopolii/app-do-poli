import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surfaceContainer;
    final shape = theme.cardTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: cardColor,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: .10),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(17), child: child),
    );
  }
}
