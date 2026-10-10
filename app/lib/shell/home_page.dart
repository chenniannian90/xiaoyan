import 'package:flutter/material.dart';

import '../content/library.dart';
import '../content/models.dart';
import '../theme/design_tokens.dart';
import 'topic_list_page.dart';
import 'widgets/sticker_card.dart';

/// 首页:两个板块入口。数学乐园走叶子绿,科学小实验走天空蓝。
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.library});

  final ContentLibrary library;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // 整块竖着居中:只有两个入口,贴顶会让下半屏空一大片,像没加载出来
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                '小妍乐园',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: DesignTokens.gapS),
              const Text(
                '今天想玩哪一个呀?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: DesignTokens.inkSoft),
              ),
              const SizedBox(height: DesignTokens.gapL * 1.5),
              _ModuleCard(
                emoji: '🔢',
                title: '数学乐园',
                subtitle: '看不懂的题,变成动画讲给你听',
                color: DesignTokens.leafGreen,
                onTap: () => _open(context, TopicKind.math, '数学乐园'),
              ),
              const SizedBox(height: DesignTokens.gap),
              _ModuleCard(
                emoji: '🧪',
                title: '科学小实验',
                subtitle: '看动画,自己动手做一遍',
                color: DesignTokens.skyBlue,
                onTap: () => _open(context, TopicKind.science, '科学小实验'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, TopicKind kind, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TopicListPage(kind: kind, title: title, library: library),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.all(DesignTokens.gapL),
      child: Row(
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: DesignTokens.card,
              shape: BoxShape.circle,
              border: Border.all(color: DesignTokens.outline, width: DesignTokens.borderWidth),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: DesignTokens.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 32),
        ],
      ),
    );
  }
}
