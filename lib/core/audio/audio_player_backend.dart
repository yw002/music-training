import 'dart:typed_data';

/// 播放后端抽象（架构 §1.2 / §3.4）。
///
/// `SoLoudAudioBackend` 是 `flutter_soloud 4.1.x` 的实现；合成的 WAV（纯 Dart 层）
/// 通过 `load` 灌入后端，后端只负责「忠实播放 PCM」，不做任何 DSP——这是「四端
/// 听感一致」的关键（架构 §1.2.1）。
///
/// ───────────────────────────────────────────────────────────────────────────
/// §1.2.4 风险与逃生路线（设计，本期不实现，但必须写明）：
///
/// `flutter_soloud` 是 FFI 插件，需要每端原生编译（Windows 需 VS C++ 工具链、
/// iOS/macOS 需 CocoaPods / SwiftPM）。**若某端编译失败**：只需新增
/// `lib/core/audio/fallback_file_backend.dart` 实现本接口——把 WAV 写到
/// `getTemporaryDirectory()` 再用 `audioplayers` 的 `DeviceFileSource` 播放，
/// `positionOf()` 退化为 `Stopwatch`。变更范围 ≤ 1 个文件、≈150 行，
/// `AppBootstrap` 里把 `SoLoudBackend` 换成 `FallbackFileBackend` 即可，合成层与
/// `AudioService` 接口完全不受影响。
/// ───────────────────────────────────────────────────────────────────────────
abstract class AudioPlayerBackend {
  /// 初始化引擎。
  Future<void> init(int sampleRate, int bufferSize);

  /// 把一个 WAV 字节流加载成可播放的 [LoadedAudio]。
  Future<LoadedAudio> load(String key, Uint8List wav);

  /// 卸载（释放引擎里的 source 句柄）。
  Future<void> unload(LoadedAudio audio);

  /// 播放一个已加载的音频，返回 [PlayingVoice]（同步返回句柄）。
  PlayingVoice playSource(LoadedAudio audio, double volume);

  /// 当前播放位置。
  Duration positionOf(PlayingVoice voice);

  /// 该 voice 是否仍在存活（未结束 / 未出错）。
  bool isAlive(PlayingVoice voice);

  /// 停止一个 voice。
  Future<void> stopVoice(PlayingVoice voice);

  /// 设置全局音量 [0, 1]。
  void setGlobalVolume(double volume);

  /// 关闭引擎、释放资源。
  Future<void> shutdown();
}

/// 已加载到引擎的音频句柄（架构 §3.4）。
///
/// [token] 是后端私有类型（SoLoud 里是 `AudioSource`），本层只当不透明对象传递；
/// [length] 用于事件发射节奏与降级计时。
class LoadedAudio {
  const LoadedAudio({
    required this.token,
    required this.length,
  });

  /// 后端私有句柄（SoLoud 为 `AudioSource`）。
  final Object token;

  /// 音频时长。
  final Duration length;
}

/// 正在播放的 voice 句柄（架构 §3.4）。
///
/// [token] 是后端私有类型（SoLoud 里是 `SoundHandle` 的整数表示）。
class PlayingVoice {
  const PlayingVoice({required this.token});

  /// 后端私有句柄（SoLoud 为 `SoundHandle`）。
  final Object token;
}
