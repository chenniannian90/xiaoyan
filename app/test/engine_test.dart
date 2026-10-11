import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/bricks/registry.dart';
import 'package:xiaoyan/content/loader.dart';
import 'package:xiaoyan/content/models.dart';
import 'package:xiaoyan/engine/brick.dart';
import 'package:xiaoyan/engine/scene_state.dart';
import 'package:xiaoyan/engine/timeline.dart';

/// 引擎的逻辑测试 —— 不碰界面,只验"世界演到哪里了"。
///
/// 这一层特别值得测,因为动画在手机上看不出对错:截图只能看瞬间,
/// 而这几条不变量(世界累加、补间可回拨、parallel 是同时)错了以后画面还是"有个东西在动"。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 把一包的学环节从头走一遍,返回每一步**演完之后**的世界。
  List<SceneState> playThrough(Topic topic) {
    final SceneState walk = SceneState();
    final List<SceneState> ends = <SceneState>[];
    for (final LearnStep step in topic.learn.steps) {
      buildStepTimeline(step.bricks, walk).settle();
      ends.add(walk.clone());
    }
    return ends;
  }

  group('积木认不出来就说名字', () {
    test('没听说过的积木 → UnknownBrickException,带名字', () {
      expect(
        () => brickNamed('science.magic'),
        throwsA(
          isA<UnknownBrickException>().having(
            (UnknownBrickException e) => e.name,
            'name',
            'science.magic',
          ),
        ),
      );
    });

    test('鸡蛋的 position 写错 → BrickParamException,带原文', () {
      final SceneState state = SceneState();
      final BrickCall call = BrickCall(
        brick: 'science.egg',
        params: <String, dynamic>{'position': 'sky'},
      );
      expect(
        () => brickNamed('science.egg').run(call, state),
        throwsA(
          isA<BrickParamException>().having(
            (BrickParamException e) => e.message,
            'message',
            allOf(contains('sky'), contains('bottom')),
          ),
        ),
      );
    });
  });

  group('世界是累加的 —— 新一步不会把上一步的东西抹掉', () {
    test('「盐水浮鸡蛋」五步走完,每一步的终态都对得上', () async {
      final Topic topic = await ContentRepository().load('salt-water-egg');
      final List<SceneState> ends = playThrough(topic);

      // 第 1 步:摆布景
      expect(ends[0].objects, containsAll(<String>['bench', 'cup', 'egg']));
      expect(ends[0].liquidLevel, 0);

      // 第 2 步:倒水 0.7,鸡蛋落到底
      expect(ends[1].liquidLevel, closeTo(0.7, 0.001));
      expect(ends[1].eggInCup, isTrue);
      expect(ends[1].eggLevel, closeTo(0, 0.001));
      expect(ends[1].salted, isFalse);

      // 第 3 步只挂了个牌子 —— 水必须还在(这正是"世界累加"的要害)
      expect(ends[2].highlightTarget, 'egg');
      expect(ends[2].highlightLabel, '鸡蛋更重');
      expect(ends[2].liquidLevel, closeTo(0.7, 0.001));
      expect(ends[2].eggLevel, closeTo(0, 0.001));

      // 第 4 步:倒盐 + 搅,化完
      expect(ends[3].salted, isTrue);
      expect(ends[3].saltPile, closeTo(0, 0.001));
      expect(ends[3].stirring, isFalse);
      expect(ends[3].pouring, isFalse);
      expect(ends[3].eggLevel, closeTo(0, 0.001), reason: '这一步没动鸡蛋');

      // 第 5 步:鸡蛋浮到水面
      expect(ends[4].eggLevel, closeTo(1, 0.001));
      expect(ends[4].liquidLevel, closeTo(0.7, 0.001));
    });

    test('布景是累加不是替换:先摆杯子,再补一张台子,杯子还在', () {
      final SceneState state = SceneState();
      brickNamed('shared.scene').run(
        BrickCall(brick: 'shared.scene', params: <String, dynamic>{'objects': <String>['cup']}),
        state,
      );
      brickNamed('shared.scene').run(
        BrickCall(brick: 'shared.scene', params: <String, dynamic>{'objects': <String>['bench']}),
        state,
      );
      expect(state.objects, <String>{'cup', 'bench'});
    });
  });

  group('时间线', () {
    /// 两块各有时长的积木:倒水 900ms、鸡蛋下沉 520ms。
    List<BrickCall> pair({required bool parallel}) => <BrickCall>[
          BrickCall(
            brick: 'science.liquid',
            params: <String, dynamic>{'kind': 'water', 'solute': 'none', 'level': 0.7},
          ),
          BrickCall(
            brick: 'science.egg',
            parallel: parallel,
            params: <String, dynamic>{'position': 'bottom', 'motion': 'sink'},
          ),
        ];

    test('默认一块演完再演下一块:总时长是两块相加', () {
      final SceneTimeline t = buildStepTimeline(pair(parallel: false), SceneState());
      expect(t.duration, const Duration(milliseconds: 900 + 520));
    });

    test('标了 parallel:true 就同时开始:总时长取长的那个', () {
      final SceneTimeline t = buildStepTimeline(pair(parallel: true), SceneState());
      expect(t.duration, const Duration(milliseconds: 900));
    });

    test('只有瞬时动作(摆布景)的一步 → 没有时长,但状态已经生效', () {
      final SceneState state = SceneState();
      final SceneTimeline t = buildStepTimeline(
        <BrickCall>[
          BrickCall(brick: 'shared.scene', params: <String, dynamic>{'objects': <String>['cup']}),
        ],
        state,
      );
      expect(t.duration, Duration.zero);
      expect(state.objects, contains('cup'));
    });

    test('seek 只取决于传进来的时刻:拨两次一个样,往回拨也一个样', () {
      final SceneState state = SceneState();
      final SceneTimeline t = buildStepTimeline(pair(parallel: false), state);
      const Duration half = Duration(milliseconds: 450);

      t.seek(half);
      final double first = state.liquidLevel;
      t.seek(const Duration(milliseconds: 1400)); // 先跑到后面去
      t.seek(half); // 再拨回来

      expect(state.liquidLevel, first);
      expect(state.liquidLevel, greaterThan(0));
      expect(state.liquidLevel, lessThan(0.7));
    });

    test('鸡蛋是后演的那块:水还没倒完时它还吊在杯口上面', () {
      final SceneState state = SceneState();
      final SceneTimeline t = buildStepTimeline(pair(parallel: false), state);

      t.seek(const Duration(milliseconds: 100)); // 还在倒水
      expect(state.eggLevel, greaterThan(1), reason: 'eggLevel > 1 = 画在杯口外头');
      expect(state.liquidLevel, greaterThan(0));

      t.seek(const Duration(milliseconds: 1420 + 1)); // 两块都演完
      expect(state.eggLevel, closeTo(0, 0.001));
    });
  });
}
