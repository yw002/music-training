import 'dart:async';
import 'dart:typed_data';

import 'package:interval_ear/core/audio/audio_player_backend.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/cache/lru_map.dart';
import 'package:interval_ear/core/audio/synth/pcm_synthesizer.dart';
import 'package:interval_ear/core/audio/synth/sequence_builder.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 三级音频缓冲缓存（架构 §3.4 / T08 验收 4）。
///
/// - L1：单音 PCM（[Float32List]）——37 音 × 2 音色，容量 [AppConfig.noteCacheCapacity]。
/// - L2：序列 WAV + 时间线（[SequenceRender]）——容量 [AppConfig.sequenceCacheCapacity]。
/// - L3：已加载到音频引擎的 [LoadedAudio]——容量 [AppConfig.loadedSourceCacheCapacity]。
///
/// **缓存键不含题目 ID**（T08 验收 5）：[AudioSequenceSpec.cacheKey] 只含音程/根音/
/// 音色/时长，重播同一题命中 L2，不重复合成。
class AudioBufferCache {
  /// 构造。
  AudioBufferCache({
    int noteCapacity = AppConfig.noteCacheCapacity,
    int sequenceCapacity = AppConfig.sequenceCacheCapacity,
    int loadedCapacity = AppConfig.loadedSourceCacheCapacity,
    this.backend,
  })  : _notes = LruMap<String, Float32List>(noteCapacity),
        _sequences = LruMap<String, SequenceRender>(sequenceCapacity),
        _loaded = LruMap<String, LoadedAudio>(
          loadedCapacity,
          onEvicted: backend == null
              ? null
              : (LoadedAudio audio) => unawaited(backend.unload(audio)),
        );

  /// 播放后端（用于 L3 真正加载到引擎）。`null` 时 L3 用占位 [LoadedAudio]，
  /// 便于纯单测（不依赖 flutter_soloud 原生编译）。
  final AudioPlayerBackend? backend;

  final LruMap<String, Float32List> _notes;
  final LruMap<String, SequenceRender> _sequences;
  final LruMap<String, LoadedAudio> _loaded;

  /// 实际发起合成的次数（区别于缓存命中），供命中率测试断言。
  int buildCount = 0;

  /// L1：取单音 PCM，缺失则合成并缓存。
  Float32List getNotePcm(int midi, Timbre timbre, int durationMs) {
    final String key = _noteKey(midi, timbre, durationMs);
    final Float32List? cached = _notes[key];
    if (cached != null) {
      return cached;
    }
    final Float32List pcm = PcmSynthesizer.renderNote(
        midi, timbre, durationMs, AppConfig.sampleRate);
    _notes[key] = pcm;
    return pcm;
  }

  /// L2：取序列渲染结果，缺失则构建并缓存。
  ///
  /// 返回的是**同一缓存实例**（命中时 `identical` 为真），供调用方判断是否命中。
  SequenceRender getOrBuild(AudioSequenceSpec spec) {
    final String key = spec.cacheKey();
    final SequenceRender? cached = _sequences[key];
    if (cached != null) {
      return cached;
    }
    final SequenceRender render = SequenceBuilder.build(spec);
    _sequences[key] = render;
    buildCount++;
    return render;
  }

  /// L3：把 WAV 加载成 [LoadedAudio]，缺失则加载并缓存。
  ///
  /// 有 [backend] 时走真实加载；无后端（纯单测）时用占位 [LoadedAudio]
  /// （token = key，length 由 WAV 数据长度反推），保证事件发射节奏正确。
  Future<LoadedAudio> getLoaded(String key, Uint8List wav) async {
    final LoadedAudio? cached = _loaded[key];
    if (cached != null) {
      return cached;
    }
    final AudioPlayerBackend? backend = this.backend;
    if (backend != null) {
      final LoadedAudio loaded = await backend.load(key, wav);
      _loaded[key] = loaded;
      return loaded;
    }
    final int dataSize = wav.length > 44 ? wav.length - 44 : 0;
    final int samples = dataSize ~/ 2;
    final Duration length = Duration(
      microseconds: (samples * 1000000) ~/ AppConfig.sampleRate,
    );
    final LoadedAudio placeholder = LoadedAudio(token: key, length: length);
    _loaded[key] = placeholder;
    return placeholder;
  }

  /// 是否已加载（L3 命中判断）。
  bool isLoaded(String key) => _loaded.containsKey(key);

  /// 清空全部三级缓存。
  void clear() {
    _notes.clear();
    _sequences.clear();
    _loaded.clear();
    buildCount = 0;
  }

  /// 卸载所有原生音源并清空缓存。
  Future<void> dispose() async {
    final AudioPlayerBackend? backend = this.backend;
    final List<LoadedAudio> loaded = _loaded.values.toList(growable: false);
    _loaded.clear(notifyEvicted: false);
    if (backend != null) {
      await Future.wait(loaded.map(backend.unload));
    }
    _notes.clear();
    _sequences.clear();
    buildCount = 0;
  }

  /// L1 键：不含题目 ID，只含音高/音色/时长。
  static String _noteKey(int midi, Timbre timbre, int durationMs) =>
      'n$midi-${timbre.storageId}-$durationMs';
}
