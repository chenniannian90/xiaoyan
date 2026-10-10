import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// 动森风的"贴纸"卡片:大圆角 + 粗描边 + 浅影。可点可不点。
class StickerCard extends StatelessWidget {
  const StickerCard({
    super.key,
    required this.child,
    this.color = DesignTokens.card,
    this.onTap,
    this.padding = const EdgeInsets.all(DesignTokens.gap),
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(DesignTokens.radiusCard);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: DesignTokens.outline, width: DesignTokens.borderWidth),
        boxShadow: DesignTokens.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 详情页里的一块:小标题 + 内容。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.accent = DesignTokens.leafGreen,
  });

  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      padding: const EdgeInsets.all(DesignTokens.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: DesignTokens.gapS),
          child,
        ],
      ),
    );
  }
}
