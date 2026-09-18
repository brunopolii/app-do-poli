import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = theme.extension<_PoliThemeExtension>();
    final cardColor = settings?.cardColor ?? theme.colorScheme.surfaceContainer;
    final borderColor = settings?.cardBorderColor ?? theme.colorScheme.outline;
    final cardOpacity = settings?.cardOpacity ?? .90;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      color: cardColor.withValues(alpha: cardOpacity),
      shadowColor: theme.colorScheme.shadow.withValues(alpha: .10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(17), child: child),
    );
  }
}

class _PoliThemeExtension extends ThemeExtension<_PoliThemeExtension> {
  final Color cardColor;
  final double cardOpacity;
  final Color cardBorderColor;
  const _PoliThemeExtension({required this.cardColor, required this.cardOpacity, required this.cardBorderColor});
  @override _PoliThemeExtension copyWith({Color? cardColor,double? cardOpacity,Color? cardBorderColor}) =>
      _PoliThemeExtension(cardColor:cardColor??this.cardColor,cardOpacity:cardOpacity??this.cardOpacity,cardBorderColor:cardBorderColor??this.cardBorderColor);
  @override _PoliThemeExtension lerp(covariant _PoliThemeExtension? other,double t){
    if(other==null)return this;
    return _PoliThemeExtension(
      cardColor:Color.lerp(cardColor,other.cardColor,t)!,
      cardOpacity:cardOpacity+(other.cardOpacity-cardOpacity)*t,
      cardBorderColor:Color.lerp(cardBorderColor,other.cardBorderColor,t)!,
    );
  }
}
