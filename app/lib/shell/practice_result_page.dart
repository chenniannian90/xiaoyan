import 'package:flutter/material.dart';

import '../content/models.dart';
import '../theme/design_tokens.dart';
import 'widgets/sticker_card.dart';

/// 练完的结算页:几颗星、一句鼓励、回家。
///
/// 没有分数没有排名 —— 星星只数「一次做对」的,错过再对的题不给星,
/// 但错题本里那道题翻了身,这本身就该被夸一句。
class PracticeResultPage extends StatelessWidget {
  const PracticeResultPage({
    super.key,
    required this.topic,
    required this.stars,
    required this.total,
  });

  final Topic topic;
  final int stars;
  final int total;

  @override
  Widget build(BuildContext context) {
    final String cheer = switch (stars) {
      0 => '没关系,动画再看一遍,下次一定行!',
      _ when stars == total => '全对!一次都没错,你真是太棒了!',
      _ => '$total 题里有 $stars 题一次就对,好厉害!',
    };

    return Scaffold(
      appBar: AppBar(title: Text(topic.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.pagePadding),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Text(topic.emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: DesignTokens.gap),
              Text(
                '练完啦!',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: DesignTokens.gap),
              StickerCard(
                child: Column(
                  children: <Widget>[
                    Text(
                      '⭐' * stars + '☆' * (total - stars),
                      style: const TextStyle(fontSize: 44, letterSpacing: 6),
                    ),
                    const SizedBox(height: DesignTokens.gapS),
                    Text(
                      '$stars / $total',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.leafGreenDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.gap),
              Text(
                cheer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: DesignTokens.inkSoft,
                ),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('practice.home'),
                onPressed: () => Navigator.of(context).popUntil((Route<Object?> r) => r.isFirst),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.leafGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(60),
                  textStyle: (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                      .copyWith(fontSize: 19, fontWeight: FontWeight.w900),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                  ),
                ),
                child: const Text('回到首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
