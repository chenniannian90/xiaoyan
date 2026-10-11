import 'dart:convert';

/// 内容包格式不对时抛这个。message 里要能看出是哪个包、哪个字段出的问题 ——
/// 内容是数据驱动的,坏包必须报得清楚,不能默默当 null 混过去。
class ContentFormatException implements Exception {
  ContentFormatException(this.message);

  final String message;

  @override
  String toString() => '内容包格式错误:$message';
}

enum TopicKind {
  math,
  science;

  static TopicKind parse(String raw, String origin) {
    for (final TopicKind kind in TopicKind.values) {
      if (kind.name == raw) return kind;
    }
    throw ContentFormatException('$origin 的 kind 只能是 math 或 science,现在是 "$raw"');
  }
}

/// 一个内容包。公共字段两类包都有,分叉字段按 [kind] 二选一:
/// math 带 [practice],science 带 [experiment](见 content-schema/topic.schema.json)。
class Topic {
  const Topic({
    required this.kind,
    required this.slug,
    required this.title,
    required this.grade,
    required this.category,
    required this.difficulty,
    required this.emoji,
    required this.learn,
    this.practice,
    this.experiment,
  });

  final TopicKind kind;
  final String slug;
  final String title;
  final int grade;
  final String category;
  final int difficulty;
  final String emoji;
  final Learn learn;
  final Practice? practice;
  final Experiment? experiment;

  /// 解析一份 topic.json。[origin] 用于报错定位(通常传 slug)。
  factory Topic.parse(String source, {required String origin}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ContentFormatException('$origin 不是合法 JSON:${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ContentFormatException('$origin 的顶层应该是一个对象');
    }
    return Topic.fromJson(decoded, origin: origin);
  }

  factory Topic.fromJson(Map<String, dynamic> json, {required String origin}) {
    // 先查顶层的必填字段,再往里查 —— 坏包要报最外层缺的那个,别一上来就报嵌套里的。
    final TopicKind kind = TopicKind.parse(_str(json, 'kind', origin), origin);
    final String slug = _str(json, 'slug', origin);
    final String title = _str(json, 'title', origin);
    final int grade = _int(json, 'grade', origin);
    final String category = _str(json, 'category', origin);
    final int difficulty = _int(json, 'difficulty', origin);
    final String emoji = _str(json, 'emoji', origin);

    final Learn learn = Learn.fromJson(
      _obj(json['learn'], '$origin 的 learn'),
      origin: '$origin.learn',
    );

    final Practice? practice = switch (json['practice']) {
      null => null,
      final Object v => Practice.fromJson(_obj(v, '$origin 的 practice'), origin: '$origin.practice'),
    };
    final Experiment? experiment = switch (json['experiment']) {
      null => null,
      final Object v => Experiment.fromJson(_obj(v, '$origin 的 experiment'), origin: '$origin.experiment'),
    };

    if (kind == TopicKind.math && practice == null) {
      throw ContentFormatException('$origin 是 math 包,但缺 practice(练习题目集)');
    }
    if (kind == TopicKind.science && experiment == null) {
      throw ContentFormatException('$origin 是 science 包,但缺 experiment(动手做环节)');
    }

    return Topic(
      kind: kind,
      slug: slug,
      title: title,
      grade: grade,
      category: category,
      difficulty: difficulty,
      emoji: emoji,
      learn: learn,
      practice: practice,
      experiment: experiment,
    );
  }
}

/// 学环节:一串动画步骤,每步配一句语音。
class Learn {
  const Learn({required this.steps});

  final List<LearnStep> steps;

  factory Learn.fromJson(Map<String, dynamic> json, {required String origin}) {
    return Learn(
      steps: _list(json, 'steps', origin)
          .map((Object? e) => LearnStep.fromJson(
                _obj(e, '$origin 的一步'),
                origin: origin,
              ))
          .toList(),
    );
  }
}

/// 学环节的一步:执行 1..n 块积木,同步播一句语音。
class LearnStep {
  const LearnStep({
    required this.bricks,
    required this.text,
    required this.audio,
  });

  final List<BrickCall> bricks;
  final String text;
  final String audio;

  factory LearnStep.fromJson(Map<String, dynamic> json, {required String origin}) {
    return LearnStep(
      bricks: BrickCall.listFrom(json, origin: origin),
      text: _str(json, 'text', origin),
      audio: _str(json, 'audio', origin),
    );
  }
}

/// 调用一块积木并给参数。
///
/// 一步里可以有多块积木,默认**一块演完再演下一块**(同一镜头里的连续动作)。
/// 想让某块跟上一块**同时开始**,给它写 `"parallel": true` ——
/// 比如「水变成蓝色」和「同时冒气泡」。
class BrickCall {
  const BrickCall({
    required this.brick,
    this.params = const <String, dynamic>{},
    this.parallel = false,
  });

  final String brick;
  final Map<String, dynamic> params;
  final bool parallel;

  factory BrickCall.fromJson(Map<String, dynamic> json, {required String origin}) {
    final Object? params = json['params'];
    return BrickCall(
      brick: _str(json, 'brick', origin),
      params: params == null
          ? const <String, dynamic>{}
          : _obj(params, '$origin 的 params'),
      parallel: json['parallel'] == true,
    );
  }

  static List<BrickCall> listFrom(Map<String, dynamic> json, {required String origin}) {
    return _list(json, 'bricks', origin)
        .map((Object? e) => BrickCall.fromJson(_obj(e, '$origin 里的一块积木'), origin: origin))
        .toList();
  }
}

/// 数学包专有:练习题目集。
class Practice {
  const Practice({required this.items});

  final List<PracticeItem> items;

  factory Practice.fromJson(Map<String, dynamic> json, {required String origin}) {
    return Practice(
      items: _list(json, 'items', origin)
          .map((Object? e) => PracticeItem.fromJson(_obj(e, '$origin 的一题'), origin: origin))
          .toList(),
    );
  }
}

class PracticeItem {
  const PracticeItem({required this.template, required this.data, this.hint});

  final String template;
  final Map<String, dynamic> data;
  final String? hint;

  factory PracticeItem.fromJson(Map<String, dynamic> json, {required String origin}) {
    return PracticeItem(
      template: _str(json, 'template', origin),
      data: _obj(json['data'], '$origin 的 data'),
      hint: _optStr(json, 'hint'),
    );
  }
}

/// 科学包专有:动手做环节。safety 强制非空 —— 没写安全提示的实验包不许进 App。
class Experiment {
  const Experiment({
    required this.materials,
    required this.safety,
    required this.steps,
    required this.recordOptions,
    this.adultNote,
  });

  final List<MaterialItem> materials;
  final List<String> safety;
  final List<ExperimentStep> steps;
  final List<RecordOption> recordOptions;
  final String? adultNote;

  factory Experiment.fromJson(Map<String, dynamic> json, {required String origin}) {
    return Experiment(
      materials: _list(json, 'materials', origin)
          .map((Object? e) => MaterialItem.fromJson(_obj(e, '$origin 的一份材料'), origin: origin))
          .toList(),
      safety: _list(json, 'safety', origin)
          .map((Object? e) => e is String && e.isNotEmpty
              ? e
              : throw ContentFormatException('$origin 的 safety 里有一条不是文字'))
          .toList(),
      steps: _list(json, 'steps', origin)
          .map((Object? e) => ExperimentStep.fromJson(_obj(e, '$origin 的一步'), origin: origin))
          .toList(),
      recordOptions: _list(json, 'recordOptions', origin)
          .map((Object? e) => RecordOption.fromJson(_obj(e, '$origin 的一个现象选项'), origin: origin))
          .toList(),
      adultNote: _optStr(json, 'adultNote'),
    );
  }
}

class MaterialItem {
  const MaterialItem({required this.name, required this.amount, this.note});

  final String name;
  final String amount;
  final String? note;

  factory MaterialItem.fromJson(Map<String, dynamic> json, {required String origin}) {
    return MaterialItem(
      name: _str(json, 'name', origin),
      amount: _str(json, 'amount', origin),
      note: _optStr(json, 'note'),
    );
  }
}

/// 动手做的一步。record 为 true 时,这一步做完要拍照 + 选现象,进实验册。
class ExperimentStep {
  const ExperimentStep({
    required this.text,
    required this.audio,
    required this.record,
    this.bricks = const <BrickCall>[],
  });

  final String text;
  final String audio;
  final bool record;
  final List<BrickCall> bricks;

  factory ExperimentStep.fromJson(Map<String, dynamic> json, {required String origin}) {
    final Object? bricks = json['bricks'];
    return ExperimentStep(
      text: _str(json, 'text', origin),
      audio: _str(json, 'audio', origin),
      record: json['record'] == true,
      bricks: bricks == null
          ? const <BrickCall>[]
          : BrickCall.listFrom(_obj(bricks, '$origin 的 bricks'), origin: origin),
    );
  }
}

class RecordOption {
  const RecordOption({required this.id, required this.label, this.emoji});

  final String id;
  final String label;
  final String? emoji;

  factory RecordOption.fromJson(Map<String, dynamic> json, {required String origin}) {
    return RecordOption(
      id: _str(json, 'id', origin),
      label: _str(json, 'label', origin),
      emoji: _optStr(json, 'emoji'),
    );
  }
}

// ---- 解析小工具:错就报「哪个包、哪个字段」,不要静默 null ----

Map<String, dynamic> _obj(Object? value, String where) {
  if (value is Map<String, dynamic>) return value;
  throw ContentFormatException('$where 应该是一个对象');
}

String _str(Map<String, dynamic> json, String key, String where) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw ContentFormatException('$where 缺字段 $key(或它不是非空字符串)');
  }
  return value;
}

String? _optStr(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

int _int(Map<String, dynamic> json, String key, String where) {
  final Object? value = json[key];
  if (value is! int) {
    throw ContentFormatException('$where 缺字段 $key(或它不是整数)');
  }
  return value;
}

List<Object?> _list(Map<String, dynamic> json, String key, String where) {
  final Object? value = json[key];
  if (value is! List || value.isEmpty) {
    throw ContentFormatException('$where 缺字段 $key(或它不是非空数组)');
  }
  return value;
}
