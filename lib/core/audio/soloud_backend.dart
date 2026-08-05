import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:interval_ear/core/audio/audio_player_backend.dart';
import 'package:interval_ear/core/constants/app_config.dart';

/// 基于 `flutter_soloud 4.1.x` 的播放后端（架构 §1.2）。
///
/// 只做「忠实播放 PCM」：合成层（纯 Dart）把 WAV 喂进来，本后端用 SoLoud 引擎
/// 播放并提供采样级 `getPosition`。所有原生异常都在方法内吞掉，向上只返回安全默认值
/// 或抛「可控」异常——`SoLoudAudioService` 据此降级，绝不崩溃（T09 验收 4）。
class SoLoudBackend implements AudioPlayerBackend {
  /// 构造。[soloud] 默认用单例 [SoLoud.instance]（便于测试注入）。
  SoLoudBackend({SoLoud? soloud}) : _soloud = soloud ?? SoLoud.instance;

  final SoLoud _soloud;

  /// 记录初始化时的采样率，用于把 WAV 字节长度反推成音频时长。
  int _sampleRate = AppConfig.sampleRate;

  @override
  Future<void> init(int sampleRate, int bufferSize) async {
    _sampleRate = sampleRate;
    // 失败（如原生未编译）由调用方捕获 → 标记 isAvailable=false → 降级 Fake。
    await _soloud.init(
      sampleRate: sampleRate,
      bufferSize: bufferSize,
      lowLatency: true,
    );
  }

  @override
  Future<LoadedAudio> load(String key, Uint8List wav) async {
    final AudioSource source = await _soloud.loadMem(key, wav, mode: LoadMode.memory);
    final int samples = wav.length > 44 ? (wav.length - 44) ~/ 2 : 0;
    final Duration length =
        Duration(microseconds: (samples * 1000000) ~/ _sampleRate);
    return LoadedAudio(token: source, length: length);
  }

  @override
  Future<void> unload(LoadedAudio audio) async {
    final Object token = audio.token;
    if (token is AudioSource) {
      try {
        await _soloud.disposeSource(token);
      } catch (_) {
        // 已释放 / 引擎未初始化：忽略。
      }
    }
  }

  @override
  PlayingVoice playSource(LoadedAudio audio, double volume) {
    final Object token = audio.token;
    if (token is! AudioSource) {
      // 非法 / 未加载：返回空 voice，调用方按「未播放」处理。
      return const PlayingVoice(token: -1);
    }
    try {
      // `play` 同步返回 SoundHandle（底层 int 表示）。
      final SoundHandle handle = _soloud.play(token, volume: volume);
      return PlayingVoice(token: handle.id);
    } catch (_) {
      return const PlayingVoice(token: -1);
    }
  }

  @override
  Duration positionOf(PlayingVoice voice) {
    final Object token = voice.token;
    if (token is! int) {
      return Duration.zero;
    }
    try {
      return _soloud.getPosition(SoundHandle(token));
    } catch (_) {
      // 句柄已失效：返回零位置，由 isAlive 判定结束。
      return Duration.zero;
    }
  }

  @override
  bool isAlive(PlayingVoice voice) {
    final Object token = voice.token;
    if (token is! int || token < 0) {
      return false;
    }
    try {
      return _soloud.getIsValidVoiceHandle(SoundHandle(token));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stopVoice(PlayingVoice voice) async {
    final Object token = voice.token;
    if (token is! int || token < 0) {
      return;
    }
    try {
      await _soloud.stop(SoundHandle(token));
    } catch (_) {
      // 已停止 / 失效：忽略。
    }
  }

  @override
  void setGlobalVolume(double volume) {
    try {
      _soloud.setGlobalVolume(volume.clamp(0.0, 1.0));
    } catch (_) {
      // 引擎未初始化：忽略。
    }
  }

  @override
  Future<void> shutdown() async {
    try {
      _soloud.deinit();
    } catch (_) {
      // 已关闭 / 未初始化：忽略。
    }
  }
}
