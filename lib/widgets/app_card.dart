import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = theme.extension<PoliThemeExtension>();
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

class PoliThemeExtension extends ThemeExtension<PoliThemeExtension> {
  final Color cardColor;
  final double cardOpacity;
  final Color cardBorderColor;
  const PoliThemeExtension({required this.cardColor, required this.cardOpacity, required this.cardBorderColor});
  @override PoliThemeExtension copyWith({Color? cardColor,double? cardOpacity,Color? cardBorderColor}) =>
      PoliThemeExtension(cardColor:cardColor??this.cardColor,cardOpacity:cardOpacity??this.cardOpacity,cardBorderColor:cardBorderColor??this.cardBorderColor);
  @override PoliThemeExtension lerp(covariant PoliThemeExtension? other,double t){
    if(other==null)return this;
    return PoliThemeExtension(
      cardColor:Color.lerp(cardColor,other.cardColor,t)!,
      cardOpacity:cardOpacity+(other.cardOpacity-cardOpacity)*t,
      cardBorderColor:Color.lerp(cardBorderColor,other.cardBorderColor,t)!,
    );
  }
}
