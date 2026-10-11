import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'content/library.dart';
import 'journal/journal_scope.dart';
import 'journal/journal_store.dart';
import 'media/photo_taker.dart';
import 'shell/home_page.dart';
import 'theme/design_tokens.dart';
import 'wrong/wrong_book.dart';
import 'wrong/wrong_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 内容包随 App 打包,启动时一次读完,之后界面全同步取用
  final ContentLibrary library = await ContentLibrary.load();
  final JournalStore journal = await _openJournal();
  final WrongBookStore wrongBook = await _openWrongBook();
  runApp(XiaoyanApp(library: library, journal: journal, wrongBook: wrongBook));
}

/// 打开实验册。
///
/// **开不了也不能让 App 起不来** —— 存不了实验册只是少一个功能,不该是一块黑屏。
/// 这时候退回内存实现:这一次能用,关掉就没了。
Future<JournalStore> _openJournal() async {
  // 照片要落在 App 自己的目录里,顺手在这儿问一次,界面里就能同步拼路径
  try {
    AppPaths.documentsDir = (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    // 拿不到目录:这一台设备上照片存不了,文字记录照旧
  }
  try {
    await Hive.initFlutter();
    return HiveJournalStore();
  } catch (_) {
    return MemoryJournalStore();
  }
}

/// 打开错题本。兜底逻辑跟实验册一模一样:Hive 起不来就退内存。
Future<WrongBookStore> _openWrongBook() async {
  try {
    await Hive.initFlutter();
    return HiveWrongBookStore();
  } catch (_) {
    return MemoryWrongBookStore();
  }
}

class XiaoyanApp extends StatelessWidget {
  const XiaoyanApp({
    super.key,
    required this.library,
    required this.journal,
    required this.wrongBook,
  });

  final ContentLibrary library;
  final JournalStore journal;
  final WrongBookStore wrongBook;

  @override
  Widget build(BuildContext context) {
    // 两个 scope 都套在 MaterialApp **外面**:这样它们才是所有路由的祖先,
    // 从首页推出去的做环节、练习、实验册、错题本都能读到。
    return WrongBookScope(
      store: wrongBook,
      child: JournalScope(
        store: journal,
        child: MaterialApp(
          title: '小妍乐园',
          debugShowCheckedModeBanner: false,
          theme: buildXiaoyanTheme(),
          home: HomePage(library: library),
        ),
      ),
    );
  }
}
