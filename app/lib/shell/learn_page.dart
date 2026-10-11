import 'package:flutter/material.dart';

import '../audio/speaker.dart';
import '../bricks/registry.dart';
import '../content/models.dart';
import '../engine/scene_state.dart';
import '../engine/timeline.dart';
import '../theme/design_tokens.dart';
import 'widgets/step_widgets.dart';
import 'widgets/sticker_card.dart';

/// 学环节:一步一步演动画,同步念那句话。
///
/// 三个关键约定:
/// 1. **世界是累加的**。第 3 步只高亮一下、什么也不倒,可第 2 步倒的水必须还在
///    杯里 —— 所以 [SceneState] 由这一页持有,跨步骤不重置。
/// 2. **每一步都从"这一步刚开始"的样子重演**。所以开始时先把世界倒回快照,
///    再重新排时间线。往回看、重播,靠的都是这一手。
/// 3. **演完就停住**,等小妍自己按「下一步」。不自动往下跳 —— 她要盯着看多久都行。
class LearnPage extends StatefulWidget {
  const LearnPage({super.key, required this.topic, this.speaker, this.startIndex});

  final Topic topic;

  /// 测试塞假实现进来。真机上留空,自己起 [PhoneSpeaker]。
  final Speaker? speaker;

  /// 直接落到第几步(从 0 数)。练习连错 3 次时用它送回对应的那一步;
  /// 不传从头看。
  final int? startIndex;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> with SingleTickerProviderStateMixin {
  static const StepButtonKeys _keys = StepButtonKeys(
    back: Key('learn.back'),
    replay: Key('learn.replay'),
    next: Key('learn.next'),
  );

  late final Speaker _speaker = widget.speaker ?? PhoneSpeaker();
  late final AnimationController _clock = AnimationController(vsync: this);

  /// 当前世界。跨步骤一直留着 —— 见类注释第 1 条。
  final SceneState _scene = SceneState();

  late final List<LearnStep> _steps = widget.topic.learn.steps;

  /// 每一步开头世界的快照,以及这一步排时间线时踩的坑(没坑就是 null)。
  /// 一进页面就算好:步骤就几步,重演一遍比"边走边存、退回时再倒着算"简单得多。
  late final List<SceneState> _starts;
  late final List<Object?> _errors;

  int _index = 0;
  SceneTimeline _timeline = SceneTimeline.empty;

  /// 这一步要演多久。_clock.duration 是可空的(没排过时间线的时候是 null),
  /// 自己存一份,免得每帧都要判空。
  Duration _span = Duration.zero;

  /// 这一步的动画演完了没。演完「下一步」才亮。
  bool _stepDone = false;

  @override
  void initState() {
    super.initState();
    _precompute();
    _clock.addListener(_onTick);
    _clock.addStatusListener(_onStatus);
    _enter(widget.startIndex?.clamp(0, _steps.length - 1) ?? 0);
  }

  @override
  void dispose() {
    _clock.dispose();
    _speaker.dispose();
    super.dispose();
  }

  /// 从头把每一步走一遍,记下"这一步开始时世界长什么样"。
  ///
  /// 顺手把坏积木挑出来:内容包写错名字/参数时,不能让页面白屏,
  /// 得在界面上说清楚是哪一块出了问题。
  void _precompute() {
    final SceneState walk = SceneState();
    _starts = <SceneState>[];
    _errors = <Object?>[];
    for (final LearnStep step in _steps) {
      _starts.add(walk.clone());
      try {
        buildStepTimeline(step.bricks, walk).settle();
        _errors.add(null);
      } catch (e) {
        _errors.add(e);
      }
    }
  }

  void _onTick() {
    // 每帧把世界拨到当前时刻。补间是 t 的纯函数,所以随手往回拨也不会乱。
    _timeline.seek(_span * _clock.value);
    setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    // **最后一帧要单独收尾**。AnimationController 在最后一拍先 `stop()` 再
    // notifyListeners,所以收尾那一拍 `isAnimating` 已经是 false、`value` 也停在
    // 上一次的值上 —— 只靠 listener 会永远差最后百分之几(杯子里的水差一截、
    // 鸡蛋没落到杯底)。这里直接 settle 到终点。
    _timeline.settle();
    setState(() => _stepDone = true);
  }

  /// 进第 [index] 步:倒回快照、重排时间线、开演、念那句话。
  ///
  /// 这里**不调 setState** —— initState 也会走这条路(那时还没 mount 完),
  /// 按键触发的调用方自己包一层 setState。
  void _enter(int index) {
    _speaker.stop();
    _index = index;
    _stepDone = false;
    _scene.become(_starts[index]);
    _play();
  }

  void _play() {
    final LearnStep step = _steps[_index];
    final Object? broken = _errors[_index];

    _clock.stop();
    // 「重播」走的也是这条路,而它没经过 _enter —— 得在这儿自己把旗子放下来,
    // 否则重播的时候「下一步」一直是亮的,可以一边演一边往下跳。
    _stepDone = false;

    // 念那句话。**排在错误判断前面**:动画排不出来是内容包写错了,
    // 但讲解本身还是完整的,不该连声音一起没了(错误卡上也这么写着)。
    _speaker.say(
      text: step.text,
      clipKey: 'assets/content/${widget.topic.slug}/audio/${step.audio}',
    );

    if (broken != null) {
      _timeline = SceneTimeline.empty;
      _stepDone = true;
      return;
    }

    // 排时间线时会顺手把"摆布景""挂牌子"这类瞬时动作作用到 _scene 上
    _timeline = buildStepTimeline(step.bricks, _scene);

    _span = _timeline.duration;
    if (_span == Duration.zero) {
      // 这一步没有要演的东西(只是摆个布景 / 挂块牌子),那就没有"等它演完"
      _timeline.settle();
      _stepDone = true;
      return;
    }
    _clock.duration = _span;
    _clock.forward(from: 0);
  }

  void _next() {
    if (_index < _steps.length - 1) {
      setState(() => _enter(_index + 1));
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool broken = _errors[_index] != null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: DesignTokens.gapS),
              StepDots(index: _index, total: _steps.length),
              const SizedBox(height: DesignTokens.gapS),
              SceneFrame(state: _scene),
              const SizedBox(height: DesignTokens.gap),
              // 滚一下:有的句子挺长,窄手机上不能让它顶出屏幕。
              // 外面包 Center:内容短的时候它在空出来的地方居中,
              // 不然下半屏会留一大块空白,像没加载完。
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: broken
                        ? _BrokenCard(error: _errors[_index]!, step: _index + 1)
                        : SpeechBubble(text: _steps[_index].text, talking: !_stepDone),
                  ),
                ),
              ),
              StepControls(
                keys: _keys,
                canBack: _index > 0,
                canNext: _stepDone,
                nextLabel: _index == _steps.length - 1 ? '学完了' : '下一步',
                replayLabel: '重播',
                onBack: () => setState(() => _enter(_index - 1)),
                onReplay: () => setState(_play),
                onNext: _next,
              ),
              const SizedBox(height: DesignTokens.gap),
            ],
          ),
        ),
      ),
    );
  }
}

/// 积木出了问题 —— 把话说清楚,别白屏。
class _BrokenCard extends StatelessWidget {
  const _BrokenCard({required this.error, required this.step});

  final Object error;
  final int step;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      color: const Color(0xFFFFF0EF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '第 $step 步的动画没排出来',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFFB3402F),
            ),
          ),
          const SizedBox(height: DesignTokens.gapS),
          const Text(
            '内容包这一步的积木写错了。动画先跳过,这句话还是能听:',
            style: TextStyle(fontSize: 14, color: DesignTokens.inkSoft, height: 1.4),
          ),
          const SizedBox(height: DesignTokens.gapS),
          Text(
            error.toString(),
            style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
