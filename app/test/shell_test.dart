import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/library.dart';
import 'package:xiaoyan/main.dart';

void main() {
  // 真内容包读一次。放在 setUpAll 里是因为 testWidgets 跑在 fake-async 区,
  // 在那儿读资源会踩坑(缓存下来的 future 挂在已销毁的 zone 上,永远不完成)。
  late ContentLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await ContentLibrary.load();
  });

  testWidgets('首页摆着两个板块入口', (tester) async {
    await tester.pumpWidget(XiaoyanApp(library: library));
    await tester.pumpAndSettle();

    expect(find.text('小妍乐园'), findsOneWidget);
    expect(find.text('数学乐园'), findsOneWidget);
    expect(find.text('科学小实验'), findsOneWidget);
  });

  testWidgets('点「科学小实验」进实验列表,能看到盐水浮鸡蛋', (tester) async {
    await tester.pumpWidget(XiaoyanApp(library: library));
    await tester.pumpAndSettle();

    await tester.tap(find.text('科学小实验'));
    await tester.pumpAndSettle();

    expect(find.text('盐水浮鸡蛋'), findsOneWidget);
    expect(find.text('物质与密度'), findsWidgets);
  });

  testWidgets('点实验卡片能翻到内容详情,材料/安全/步骤都在', (tester) async {
    await tester.pumpWidget(XiaoyanApp(library: library));
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

  testWidgets('数学板块还没有包,给出空状态而不是白屏', (tester) async {
    await tester.pumpWidget(XiaoyanApp(library: library));
    await tester.pumpAndSettle();

    await tester.tap(find.text('数学乐园'));
    await tester.pumpAndSettle();

    expect(find.text('还没有数学内容包'), findsOneWidget);
  });
}
