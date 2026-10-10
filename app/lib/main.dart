import 'package:flutter/material.dart';

import 'content/library.dart';
import 'shell/home_page.dart';
import 'theme/design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 内容包随 App 打包,启动时一次读完,之后界面全同步取用
  final ContentLibrary library = await ContentLibrary.load();
  runApp(XiaoyanApp(library: library));
}

class XiaoyanApp extends StatelessWidget {
  const XiaoyanApp({super.key, required this.library});

  final ContentLibrary library;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小妍乐园',
      debugShowCheckedModeBanner: false,
      theme: buildXiaoyanTheme(),
      home: HomePage(library: library),
    );
  }
}
