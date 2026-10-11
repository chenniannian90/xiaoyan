import 'package:xiaoyan/audio/speaker.dart';

/// 测试用的假喇叭。
///
/// `flutter test` 里没有平台通道,真的 [PhoneSpeaker] 一 `say` 就会掉进异常;
/// 这一份把"念了什么"记下来,好在测试里断言"这一步确实配了 s02.mp3"。
class FakeSpeaker implements Speaker {
  final List<String> said = <String>[];
  final List<String?> clips = <String?>[];
  int stops = 0;
  bool disposed = false;

  @override
  Future<void> say({required String text, String? clipKey}) async {
    said.add(text);
    clips.add(clipKey);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposed = true;
}
