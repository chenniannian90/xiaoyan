import 'package:flutter/widgets.dart';

import 'journal_store.dart';

/// 把实验册的存放处挂在树上,让深层的页面自己去取。
///
/// 不一层层往下传构造参数,是因为中间那几页(首页、列表页、详情页)只是"路过" ——
/// 它们既不读也不写实验册,却要为每次加一个跨页依赖而多一个字段。
class JournalScope extends InheritedWidget {
  const JournalScope({super.key, required this.store, required super.child});

  final JournalStore store;

  static JournalStore of(BuildContext context) {
    final JournalScope? scope = context.dependOnInheritedWidgetOfExactType<JournalScope>();
    assert(scope != null, '这一页要用实验册,但树上没有 JournalScope —— 检查 main.dart 有没有套上');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(JournalScope old) => !identical(old.store, store);
}
