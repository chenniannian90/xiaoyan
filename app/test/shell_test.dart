import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/library.dart';
import 'package:xiaoyan/journal/journal_store.dart';
import 'package:xiaoyan/main.dart';
import 'package:xiaoyan/wrong/wrong_book.dart';

void main() {
  // 真内容包读一次。放在 setUpAll 里是因为 testWidgets 跑在 fake-async 区,
  // 在那儿读资源会踩坑(缓存下来的 future 挂在已销毁的 zone 上,永远不完成)。
  late ContentLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await ContentLibrary.load();
  });

  // 这几条测的是壳层的跳转,实验册/错题本用内存实现就够 —— 不碰 Hive,不落盘。
  Widget app() => XiaoyanApp(
        library: library,
        journal: MemoryJournalStore(),
        wrongBook: MemoryWrongBookStore(),
      );

  testWidgets('首页摆着两个板块入口', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('小妍乐园'), findsOneWidget);
    expect(find.text('数学乐园'), findsOneWidget);
    expect(find.text('科学小实验'), findsOneWidget);
  });

  testWidgets('点「科学小实验」进实验列表,能看到盐水浮鸡蛋', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();

    expect(find.text('盐水浮鸡蛋'), findsOneWidget);
    expect(find.text('物质与密度'), findsWidgets);
  });

  testWidgets('点实验卡片能翻到内容详情,材料/安全/步骤都在', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('盐水浮鸡蛋'));
    await tester.pumpAndSettle();

    // 详情页比一屏长,屏幕外的部分 ListView 还没建出来,要边滚边看
    await tester.scrollUntilVisible(find.text('要准备的东西'), 300);
    expect(find.text('透明杯子'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('安全提示'), 300);
    expect(find.text('鸡蛋要轻轻放进杯子,不能扔,会碎会脏'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('往杯子里倒大半杯温水。'), 300);
    expect(find.text('往杯子里倒大半杯温水。'), findsOneWidget);
  });

  testWidgets('详情页能进「做」环节,第 1 步就在眼前', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('盐水浮鸡蛋'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('开始动手做'), 300);
    await tester.tap(find.textContaining('开始动手做'));
    await tester.pumpAndSettle();

    expect(find.textContaining('第 1 步'), findsOneWidget);
    expect(find.text('往杯子里倒大半杯温水。'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
  });

  testWidgets('科学板块能翻到「我的实验册」,空册也说得清楚', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('list.journal')));
    await tester.pumpAndSettle();

    expect(find.text('我的实验册'), findsWidgets);
    expect(find.text('实验册还是空的'), findsOneWidget);
  });

  testWidgets('数学板块看得到示例包 add-within-5', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('数学乐园'));
    await tester.pumpAndSettle();

    expect(find.textContaining('合起来数一数'), findsOneWidget);
    expect(find.text('数与代数'), findsOneWidget);
  });
}
