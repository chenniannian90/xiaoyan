import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 念一句话。
///
/// 抽象出来是因为音频插件在 `flutter test` 里跑不起来(平台通道没有对端),
/// 而学环节的界面必须能在截图测试里演一遍 —— 测试传个假的进来就行。
abstract class Speaker {
  /// 念 [text]:如果 [clipKey] 指的录音在包里存在,就放录音;否则用系统语音念文字。
  ///
  /// **不等念完就返回**。一句话两秒多,页面没法为了它干等;也正因为不等,
  /// 看的人随时按「下一步」「重播」都能用 [stop] 把它掐掉。
  Future<void> say({required String text, String? clipKey});

  Future<void> stop();

  Future<void> dispose();
}

/// 真机上用的:先录音、后系统 TTS。
class PhoneSpeaker implements Speaker {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  /// 包里到底有哪些音频资源。查一次记下来 —— 每句话都去问一遍资源清单太啰嗦。
  Set<String>? _assets;
  bool _ttsReady = false;

  @override
  Future<void> say({required String text, String? clipKey}) async {
    await stop();
    // 念不出来不该让页面崩:屏幕上本来就有字,听不到只是少一层。
    try {
      if (clipKey != null && await _hasAsset(clipKey)) {
        // AssetSource 的路径是相对 `assets/` 的,得把前缀去掉
        await _player.play(AssetSource(clipKey.replaceFirst('assets/', '')));
        return;
      }
      await _prepareTts();
      await _tts.speak(text);
    } catch (_) {
      // 忽略:这个包缺录音、设备没装中文语音、播放器被占用,都只影响"听不听得到"
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await _tts.stop();
    } catch (_) {
      // 停不下来也没什么可做的
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  Future<bool> _hasAsset(String key) async {
    _assets ??= (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet();
    return _assets!.contains(key);
  }

  Future<void> _prepareTts() async {
    if (_ttsReady) return;
    _ttsReady = true;
    // 儿童向:慢一点、高一点,跟动画的节奏合得上
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.15);
  }
}
