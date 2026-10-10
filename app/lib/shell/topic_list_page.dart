import 'package:flutter/material.dart';

import '../content/library.dart';
import '../content/models.dart';
import '../theme/design_tokens.dart';
import 'topic_detail_page.dart';
import 'widgets/sticker_card.dart';

/// 一个板块的内容包列表。数学板块列 math 包,科学板块列 science 包。
/// 内容在启动时就全读好了,这一页不碰 IO,所以没有加载态。
class TopicListPage extends StatelessWidget {
  const TopicListPage({
    super.key,
    required this.kind,
    required this.title,
    required this.library,
  });

  final TopicKind kind;
  final String title;
  final ContentLibrary library;

  @override
  Widget build(BuildContext context) {
    final List<Topic> topics = library.byKind(kind);
    final String kindLabel = kind == TopicKind.math ? '数学' : '科学';

    if (topics.isEmpty && library.broken.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: _EmptyView(text: '还没有$kindLabel内容包'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.pagePadding),
        children: <Widget>[
          if (topics.isEmpty)
            _EmptyView(text: '还没有$kindLabel内容包')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: DesignTokens.gap,
                crossAxisSpacing: DesignTokens.gap,
                childAspectRatio: 0.92,
              ),
              itemCount: topics.length,
              itemBuilder: (BuildContext context, int index) => _TopicCard(topic: topics[index]),
            ),
          for (final BrokenPack pack in library.broken) ...<Widget>[
            const SizedBox(height: DesignTokens.gap),
            _BrokenPackCard(pack: pack),
          ],
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        topic.kind == TopicKind.math ? DesignTokens.leafGreen : DesignTokens.skyBlue;
    return StickerCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TopicDetailPage(topic: topic)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(topic.emoji, style: const TextStyle(fontSize: 40)),
          const Spacer(),
          Text(
            topic.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DesignTokens.gapS),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
            ),
            child: Text(
              topic.category,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_gradeLabel(topic.grade)} · ${'★' * topic.difficulty}',
            style: const TextStyle(fontSize: 12, color: DesignTokens.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.gapL * 3),
      child: Column(
        children: <Widget>[
          const Text('🌱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: DesignTokens.gap),
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: DesignTokens.gapS),
          const Text(
            '加一个内容包就会出现在这里',
            style: TextStyle(fontSize: 14, color: DesignTokens.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// 坏包不该是白屏,也不该让别的包陪葬:单独摆一张卡,把问题原文写出来。
class _BrokenPackCard extends StatelessWidget {
  const _BrokenPackCard({required this.pack});

  final BrokenPack pack;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      color: const Color(0xFFFFE3E3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '这个内容包读不了:${pack.slug}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: DesignTokens.gapS),
          Text(pack.message, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

String _gradeLabel(int grade) {
  const List<String> numerals = <String>['', '一', '二', '三', '四', '五', '六'];
  if (grade < 1 || grade > 6) return '$grade 年级';
  return '${numerals[grade]}年级';
}
