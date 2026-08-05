import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/sfx_catalog.dart';

/// 音频服务接口（架构 §3.4）。
///
/// 这是 UI 层唯一接触的音频抽象：播放、对比、音效、停止、预加载、音量、生命周期。
/// 两种实现：[SoLoudAudioService]（真机）与 [FakeAudioService]（降级 / 测试）。
///
/// **契约要点**（工程师必须遵守，T09 验收逐条）：
/// - `playSequence`：先取消当前播放（emit `cancelled`）→ 返回**新** `playbackId`。
/// - `playComparison`：4 段渲染进**一个**缓冲区，事件带 `segmentIndex 0..3`。
/// - `stop`：幂等，emit `cancelled`，停 Ticker。
/// - `events`：**broadcast** 流；订阅者必须按 `playbackId` 过滤。
/// - `isAvailable`：`initialize()` 失败时为 `false`，UI 显示 banner（PRD §5.3-#22）。
/// - `dispose`：停播放 → 停 Ticker → 关流 → `backend.shutdown()`。
abstract class AudioService {
  /// 初始化底层引擎。失败不得抛异常，应置 [isAvailable]=false（降级到 Fake）。
  Future<void> initialize();

  /// 引擎是否可用（初始化成功）。
  bool get isAvailable;

  /// 是否正在播放某段序列。
  bool get isPlaying;

  /// 当前正在播放（或刚结束）的 playbackId。
  int get currentPlaybackId;

  /// 播放事件流（**broadcast**）。
  Stream<AudioPlaybackEvent> get events;

  /// 播放单条序列，返回新的 playbackId。会自动取消上一段（防重叠）。
  Future<int> playSequence(AudioSequenceSpec spec);

  /// 交替对比播放（错→对→错→对），返回新的 playbackId。
  Future<int> playComparison(List<AudioSequenceSpec> specs, Duration gapBetween);

  /// 播放一个音效（如答对的提示音）。
  Future<void> playSfx(SfxId id);

  /// 停止当前播放（幂等）。
  Future<void> stop();

  /// 预加载若干序列到缓存（L2/L3），避免播放时卡顿。
  Future<void> preload(Iterable<AudioSequenceSpec> specs);

  /// 设置主音量 [0, 1]。
  void setMasterVolume(double volume);

  /// 释放资源。
  Future<void> dispose();
}
