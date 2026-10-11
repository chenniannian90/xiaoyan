import 'dart:io';

import 'package:flutter/material.dart';

import '../journal/journal_entry.dart';
import '../journal/journal_scope.dart';
import '../media/photo_taker.dart';
import '../theme/design_tokens.dart';
import 'widgets/sticker_card.dart';

/// 实验册:小妍自己记下来的现象,新的在最上面。
///
/// 每一笔就是"哪次实验的第几步 + 我看到了什么 + 有没有照片"。
/// 没有对错,也不用打分 —— 这是给她回头看"我做过这些"的地方。
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  Future<List<JournalEntry>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 不能放 initState:那时候还不让读 InheritedWidget
    _future ??= JournalScope.of(context).all();
  }

  void _reload() {
    // 两个坑都在这一行上:
    // 一是 future 要先取出来 —— `setState(() => _future = ...all())` 里的 all() 会
    //   在 setState 回调里被调,虽然这次没炸,但把副作用塞进回调本来就不该干;
    // 二是**闭包必须用花括号**。`setState(() => _future = next)` 看着没事,可赋值
    //   表达式的结果就是 next 本身 —— 闭包返回了一个 Future,setState 当场断言
    //   "callback argument returned a Future"(划掉一笔时真的炸过)。
    final Future<List<JournalEntry>> next = JournalScope.of(context).all();
    setState(() {
      _future = next;
    });
  }

  Future<void> _delete(JournalEntry entry) async {
    await JournalScope.of(context).remove(entry.id);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的实验册')),
      body: FutureBuilder<List<JournalEntry>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<JournalEntry>> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<JournalEntry> entries = snap.data ?? const <JournalEntry>[];
          if (entries.isEmpty) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.all(DesignTokens.pagePadding),
            children: <Widget>[
              for (final JournalEntry e in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.gap),
                  child: Dismissible(
                    key: ValueKey<String>(e.id),
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
                    onDismissed: (_) => _delete(e),
                    child: _EntryCard(entry: e),
                  ),
                ),
            ],
          );
        },
      ),
    );
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
          Text('📒', style: TextStyle(fontSize: 56)),
          SizedBox(height: DesignTokens.gap),
          Text('实验册还是空的', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: DesignTokens.gapS),
          Text(
            '做完实验,在「做」的那几步记一笔就来了',
            style: TextStyle(fontSize: 14, color: DesignTokens.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumb(path: entry.photoPath),
              const SizedBox(width: DesignTokens.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '第 ${entry.stepIndex + 1} 步 · ${_when(entry.at)}',
                      style: const TextStyle(fontSize: 12, color: DesignTokens.inkSoft),
                    ),
                    const SizedBox(height: DesignTokens.gapS),
                    Text(
                      entry.optionLabel,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: DesignTokens.skyBlueDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.gapS),
          Text(
            entry.stepText,
            style: const TextStyle(fontSize: 14, height: 1.4, color: DesignTokens.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// 照片。**找不到就画个占位** —— 文件可能被清理工具删了、也可能这台设备上
/// 从来没拍成过,那时候不该是一块红的报错图。
class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final String? abs = path == null ? null : AppPaths.resolve(path!);
    final File? file = abs == null ? null : File(abs);
    final bool ok = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
      child: Container(
        width: 76,
        height: 76,
        color: DesignTokens.cream,
        alignment: Alignment.center,
        child: ok
            ? Image.file(file, width: 76, height: 76, fit: BoxFit.cover)
            : const Text('🔍', style: TextStyle(fontSize: 30)),
      ),
    );
  }
}

String _when(DateTime t) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
