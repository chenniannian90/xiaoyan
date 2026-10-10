import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoyan/content/library.dart';
import 'package:xiaoyan/content/loader.dart';
import 'package:xiaoyan/content/models.dart';

/// 一份最小的合法科学包,用来在测试里替掉真资源。
const String _goodPack = '''
{
  "kind": "science", "slug": "good-pack", "title": "好包", "grade": 1,
  "category": "测试", "difficulty": 1, "emoji": "✅",
  "learn": {"steps": [{"bricks": [{"brick": "shared.scene"}], "text": "看", "audio": "s01.mp3"}]},
  "experiment": {
    "materials": [{"name": "杯子", "amount": "1 个"}],
    "safety": ["别洒了"],
    "steps": [{"text": "倒水", "audio": "e01.mp3"}],
    "recordOptions": [
      {"id": "a", "label": "沉"}, {"id": "b", "label": "浮"}
    ]
  }
}
''';

class _StubRepository extends ContentRepository {
  _StubRepository({required this.slugs, required this.sources});

  final List<String> slugs;
  final Map<String, String> sources;

  @override
  Future<List<String>> listSlugs() async => slugs;

  @override
  Future<Topic> load(String slug) async => Topic.parse(sources[slug]!, origin: slug);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('内容包加载', () {
    test('salt-water-egg 读成 science 包,字段与 topic.json 对得上', () async {
      final Topic topic = await ContentRepository().load('salt-water-egg');

      expect(topic.kind, TopicKind.science);
      expect(topic.title, '盐水浮鸡蛋');
      expect(topic.grade, 2);
      expect(topic.category, '物质与密度');
      expect(topic.emoji, '🥚');

      expect(topic.learn.steps, hasLength(5));
      expect(topic.learn.steps.first.bricks.first.brick, 'shared.scene');
      expect(topic.learn.steps.first.audio, 's01.mp3');
      expect(topic.learn.steps.first.text, contains('魔术'));

      // 科学包不该带数学的 practice
      expect(topic.practice, isNull);

      final Experiment experiment = topic.experiment!;
      expect(experiment.materials, hasLength(6));
      expect(experiment.safety, isNotEmpty);
      expect(experiment.steps, hasLength(6));
      expect(
        experiment.steps.where((ExperimentStep s) => s.record).map((ExperimentStep s) => s.audio),
        containsAll(<String>['e03.mp3', 'e06.mp3']),
      );
      expect(
        experiment.recordOptions.map((RecordOption o) => o.id),
        contains('floated'),
      );
    });

    test('一步里的多块积木按顺序保留下来', () async {
      final Topic topic = await ContentRepository().load('salt-water-egg');
      final LearnStep step = topic.learn.steps[1];

      expect(step.bricks.map((BrickCall b) => b.brick).toList(), <String>[
        'science.liquid',
        'science.egg',
      ]);
      expect(step.bricks.first.params['solute'], 'none');
      expect(step.bricks.last.params['motion'], 'sink');
    });

    test('列出全部内容包,能按 kind 分成数学/科学两拨', () async {
      final List<Topic> all = await ContentRepository().loadAll();

      expect(all.map((Topic t) => t.slug), contains('salt-water-egg'));
      expect(
        all.where((Topic t) => t.kind == TopicKind.science).map((Topic t) => t.slug),
        contains('salt-water-egg'),
      );
      // v1 的数学最小示例包还没落地,这里先钉住「现在是空的」
      expect(all.where((Topic t) => t.kind == TopicKind.math), isEmpty);
    });
  });

  group('内容库', () {
    test('坏包不拖垮整页:好的照常进 topics,坏的进 broken 且带原文', () async {
      final ContentLibrary library = await ContentLibrary.load(
        repository: _StubRepository(
          slugs: <String>['good-pack', 'broken-pack'],
          sources: <String, String>{
            'good-pack': _goodPack,
            'broken-pack': '{"kind":"science","slug":"broken"}',
          },
        ),
      );

      expect(library.topics.map((Topic t) => t.slug), <String>['good-pack']);
      expect(library.broken, hasLength(1));
      expect(library.broken.single.slug, 'broken-pack');
      expect(library.broken.single.message, contains('title'));
      expect(library.byKind(TopicKind.science).map((Topic t) => t.slug), <String>['good-pack']);
    });

    test('按板块分:数学空、科学有', () async {
      final ContentLibrary library = await ContentLibrary.load(
        repository: _StubRepository(
          slugs: <String>['good-pack'],
          sources: <String, String>{'good-pack': _goodPack},
        ),
      );

      expect(library.byKind(TopicKind.math), isEmpty);
      expect(library.byKind(TopicKind.science), hasLength(1));
    });
  });

  group('内容包出错要说清楚', () {
    test('缺必填字段 → 报字段名,不默默当 null', () async {
      await expectLater(
        () => Topic.parse('{"kind":"science","slug":"x"}', origin: '测试包'),
        throwsA(
          isA<ContentFormatException>().having(
            (ContentFormatException e) => e.message,
            'message',
            contains('title'),
          ),
        ),
      );
    });

    test('JSON 根本解析不了 → 报 JSON 错,带上包名', () async {
      await expectLater(
        () => Topic.parse('{oops', origin: '测试包'),
        throwsA(
          isA<ContentFormatException>()
              .having((ContentFormatException e) => e.message, 'message', contains('JSON'))
              .having((ContentFormatException e) => e.message, 'message', contains('测试包')),
        ),
      );
    });

    test('kind 不是 math/science → 拒绝', () async {
      await expectLater(
        () => Topic.parse('{"kind":"art","slug":"x"}', origin: '测试包'),
        throwsA(
          isA<ContentFormatException>().having(
            (ContentFormatException e) => e.message,
            'message',
            contains('kind'),
          ),
        ),
      );
    });

    test('science 包缺 experiment → 拒绝', () async {
      await expectLater(
        () => Topic.parse(
          '{"kind":"science","slug":"x","title":"t","grade":2,'
          '"category":"c","difficulty":1,"emoji":"🥚",'
          '"learn":{"steps":[{"bricks":[{"brick":"shared.scene"}],'
          '"text":"hi","audio":"s01.mp3"}]}}',
          origin: '测试包',
        ),
        throwsA(
          isA<ContentFormatException>().having(
            (ContentFormatException e) => e.message,
            'message',
            contains('experiment'),
          ),
        ),
      );
    });

    test('math 包缺 practice → 拒绝', () async {
      await expectLater(
        () => Topic.parse(
          '{"kind":"math","slug":"x","title":"t","grade":1,'
          '"category":"c","difficulty":1,"emoji":"➕",'
          '"learn":{"steps":[{"bricks":[{"brick":"shared.scene"}],'
          '"text":"hi","audio":"s01.mp3"}]}}',
          origin: '测试包',
        ),
        throwsA(
          isA<ContentFormatException>().having(
            (ContentFormatException e) => e.message,
            'message',
            contains('practice'),
          ),
        ),
      );
    });

    test('读不到资源 → 提示去 pubspec.yaml 检查声明', () async {
      await expectLater(
        () => ContentRepository().load('no-such-pack'),
        throwsA(
          isA<ContentFormatException>().having(
            (ContentFormatException e) => e.message,
            'message',
            contains('pubspec.yaml'),
          ),
        ),
      );
    });
  });
}
