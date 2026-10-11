import 'package:flutter/material.dart';

import '../content/library.dart';
import '../content/models.dart';
import '../theme/design_tokens.dart';
import '../wrong/wrong_book.dart';
import '../wrong/wrong_scope.dart';
import 'practice_page.dart';
import 'widgets/sticker_card.dart';

/// 错题本:错过但还没「翻身」的题排前面,做对过的排后面。
///
/// 每条能点「再做一次」直接重练那一题。做对了当场翻身 ——
/// 这页是给小妍自己「把不会的变会的」的地方,不是红叉榜。
class WrongBookPage extends StatefulWidget {
  const WrongBookPage({super.key, required this.library});

  /// 重练要从内容包里把题找回来,所以要把库带上。
  final ContentLibrary library;

  @override
  State<WrongBookPage> createState() => _WrongBookPageState();
}

class _WrongBookPageState extends State<WrongBookPage> {
  Future<List<WrongAnswer>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= WrongBookScope.of(context).all();
  }

  void _reload() {
    final Future<List<WrongAnswer>> next = WrongBookScope.of(context).all();
    setState(() {
      _future = next;
    });
  }

  Future<void> _remove(WrongAnswer e) async {
    await WrongBookScope.of(context).remove(e.key);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错题本')),
      body: FutureBuilder<List<WrongAnswer>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<WrongAnswer>> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<WrongAnswer> entries = snap.data ?? const <WrongAnswer>[];
          if (entries.isEmpty) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.all(DesignTokens.pagePadding),
            children: <Widget>[
              for (final WrongAnswer e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.gap),
                  child: Dismissible(
                    key: ValueKey<String>(e.key),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: DesignTokens.gapL),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD9D3),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 30),
                    ),
                    onDismissed: (_) => _remove(e),
                    child: _EntryCard(entry: e, onRedo: () => _redo(e)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _redo(WrongAnswer e) {
    final Topic? topic = widget.library.topics
        .where((Topic t) => t.slug == e.slug && t.practice != null)
        .firstOrNull;
    if (topic == null) {
      // 包被删了/改名了:这条错题就成了孤儿。别崩,说清楚就行。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${e.topicTitle}」这个内容包不在了,这道题练不了')),
      );
      return;
    }
    if (e.itemIndex >= topic.practice!.items.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这道题在内容包里改没了')),
      );
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PracticePage(topic: topic, only: <int>{e.itemIndex}),
          ),
        )
        .then((_) => _reload());
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: DesignTokens.gapL * 3),
      child: Column(
        children: <Widget>[
          Text('🌟', style: TextStyle(fontSize: 56)),
          SizedBox(height: DesignTokens.gap),
          Text('错题本是空的', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: DesignTokens.gapS),
          Text(
            '练习里错过的题会自己跑到这里来',
            style: TextStyle(fontSize: 14, color: DesignTokens.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onRedo});

  final WrongAnswer entry;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      color: entry.resolved ? const Color(0xFFEFF9E7) : const Color(0xFFFFF3D6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  entry.topicTitle,
                  style: const TextStyle(fontSize: 14, color: DesignTokens.inkSoft),
                ),
              ),
              Text(
                entry.resolved ? '已会了 ✅' : '错 ${entry.wrongCount} 次',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: entry.resolved ? DesignTokens.leafGreenDeep : const Color(0xFFC77700),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.gapS),
          Text(
            entry.prompt,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.4),
          ),
          const SizedBox(height: DesignTokens.gapS),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('wrong.redo.${entry.key}'),
              onPressed: onRedo,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: Text(entry.resolved ? '再巩固一次' : '再做一次'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.ink,
                side: const BorderSide(
                  color: DesignTokens.outline,
                  width: DesignTokens.borderWidth,
                ),
                minimumSize: const Size(0, 48),
                textStyle:
                    (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                        .copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
