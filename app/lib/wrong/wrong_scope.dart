import 'package:flutter/widgets.dart';

import 'wrong_book.dart';

/// 把错题本挂在树上。跟 JournalScope 同款做法:中间页面只是"路过",
/// 不该为它们不用的东西多一个字段。
class WrongBookScope extends InheritedWidget {
  const WrongBookScope({super.key, required this.store, required super.child});

  final WrongBookStore store;

  static WrongBookStore of(BuildContext context) {
    final WrongBookScope? scope =
        context.dependOnInheritedWidgetOfExactType<WrongBookScope>();
    assert(scope != null, '这一页要用错题本,但树上没有 WrongBookScope —— 检查 main.dart 有没有套上');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(WrongBookScope old) => !identical(old.store, store);
}
