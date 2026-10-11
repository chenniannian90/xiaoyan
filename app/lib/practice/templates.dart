import 'dart:math';

import 'package:flutter/material.dart';

import '../content/models.dart';
import '../engine/scene_painter.dart';
import '../engine/scene_state.dart';
import '../theme/design_tokens.dart';

/// 一道练习题的「面」:题干、图形、选项、答案、提示。
///
/// 模板(比如「点子加法」)负责把内容包里 `practice.items[].data` 翻译成
/// 这个结构;判题、计分、连错跳回 —— 那些是页面的事,模板不掺和。
class MathQuestion {
  const MathQuestion({
    required this.ask,
    required this.face,
    required this.choices,
    required this.answer,
    this.hint,
  });

  /// 龙呼呼问的那句话,比如「2 颗和 1 颗,合起来���几颗?」
  final String ask;

  /// 题面图形(点子、小棒…… 模板自己画)。
  final Widget face;

  /// 选项(打乱顺序的活儿在模板里做,页面只管摆)。
  final List<int> choices;

  /// 正确答案。
  final int answer;

  /// 温柔的提示。做错时才亮出来。
  final String? hint;
}

/// 一个交互模板:把内容包的一题([PracticeItem])变成能摆上屏幕的 [MathQuestion]。
///
/// 跟积木同一套思路:`practice.items[].template` 是个自由字符串,
/// 注册表认它。**加一种题型 = 加一个模板类 + 注册一行**,加题不用动引擎。
abstract class PracticeTemplate {
  const PracticeTemplate();

  /// 内容包里写这个名字来引用,必须跟设计文档/内容契约里登记的一致。
  String get name;

  MathQuestion build(PracticeItem item);
}

class UnknownTemplateException implements Exception {
  const UnknownTemplateException(this.name);

  final String name;

  @override
  String toString() => '练习模板「$name」还没做出来(检查内容包的 template 字段写的是什么)';
}

/// 认识的模板。
const List<PracticeTemplate> kAllTemplates = <PracticeTemplate>[
  CountersAddTemplate(),
];

PracticeTemplate templateNamed(String name) {
  for (final PracticeTemplate t in kAllTemplates) {
    if (t.name == name) return t;
  }
  throw UnknownTemplateException(name);
}

/// 「点子加法」:左边 a 颗、右边 b 颗,中间加号,问合起来几颗。
///
/// 题面不是画出来的静态图 —— 就是学环节那套点子(SceneState + ScenePainter),
/// 学的时候看到的样子,练的时候一模一样,孩子不用重新认一遍。
class CountersAddTemplate extends PracticeTemplate {
  const CountersAddTemplate();

  @override
  String get name => 'counters-add';

  @override
  MathQuestion build(PracticeItem item) {
    final int a = _intOf(item.data, 'a');
    final int b = _intOf(item.data, 'b');
    final int answer = _intOf(item.data, 'answer');
    final List<int> choices = _choicesOf(item, answer);

    return MathQuestion(
      ask: '$a 颗和 $b 颗,合起来一共是几颗?',
      face: _CountersFace(a: a, b: b),
      choices: choices,
      answer: answer,
      hint: item.hint,
    );
  }

  static int _intOf(Map<String, dynamic> data, String key) {
    final Object? v = data[key];
    if (v is! int) {
      throw StateError('counters-add 的 data 里 $key 应该是整数,现在是 "$v"');
    }
    return v;
  }

  static List<int> _choicesOf(PracticeItem item, int answer) {
    final Object? raw = item.data['choices'];
    if (raw is! List || raw.whereType<int>().length < 2) {
      throw StateError('counters-add 的 data 里 choices 应该是至少两个整数的数组');
    }
    final List<int> choices = raw.whereType<int>().toSet().toList();
    if (!choices.contains(answer)) {
      throw StateError('counters-add 的 choices 里必须包含正确答案 $answer');
    }
    // 顺序打乱但确定性 —— 用答案自身当种子,同一道题每次的摆法一样,
    // 截图比对才稳定,孩子重做同一题也不会"背位置"变成"认按钮"。
    choices.shuffle(Random(answer * 31 + choices.length));
    return choices;
  }
}

/// 题面的点子。进题的时候一颗一颗冒出来(数一遍),然后停住等孩子答。
class _CountersFace extends StatefulWidget {
  const _CountersFace({required this.a, required this.b});

  final int a;
  final int b;

  @override
  State<_CountersFace> createState() => _CountersFaceState();
}

class _CountersFaceState extends State<_CountersFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 260 * (widget.a + widget.b) + 300),
  );

  @override
  void initState() {
    super.initState();
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (BuildContext context, _) {
        // 复用学环节的点子画笔:状态里只有点子,没有台子杯子
        final SceneState dots = SceneState()
          ..counterA = widget.a
          ..counterB = widget.b
          ..counterShown = _clock.value * (widget.a + widget.b);
        return CustomPaint(
          size: Size.infinite,
          painter: ScenePainter(state: dots, pulse: 0, labelStyle: _labelStyle(context)),
        );
      },
    );
  }

  static TextStyle _labelStyle(BuildContext context) =>
      (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
          .copyWith(fontWeight: FontWeight.w800, color: DesignTokens.ink);
}
