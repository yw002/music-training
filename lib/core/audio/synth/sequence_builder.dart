import 'dart:typed_data';

import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/synth/normalizer.dart';
import 'package:interval_ear/core/audio/synth/pcm_synthesizer.dart';
import 'package:interval_ear/core/audio/synth/wav_encoder.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 序列构建结果：一段完整的 WAV 字节流 + 与之共享参数的时间线（架构 §3.4）。
class SequenceRender {
  const SequenceRender({
    required this.wav,
    required this.timeline,
  });

  /// 单缓冲区 WAV（16-bit / 单声道），可直接喂给播放后端。
  final Uint8List wav;

  /// 与 [wav] 共享同一份参数的时间线；mark 位置与采样点误差 0 样本。
  final AudioTimeline timeline;
}

/// 序列构建器：把 [AudioSequenceSpec] 渲染成一个单缓冲区 WAV（架构 §1.3 / §5.5）。
///
/// **单缓冲区渲染**是同步方案的核心：旋律的间隔、和声的混音、交替对比的四段，
/// 全部在 Dart 层拼成**一个** WAV 再交给播放器。这样间隔是采样级精确（±0 样本）、
/// 和声两音绝对同相、交错播放不会失步——且不依赖任何定时器（架构 §1.3.1）。
abstract final class SequenceBuilder {
  /// 尾部 padding（毫秒）：音频结束后多留一小段，保证最后一音的释放尾不被切断，
  /// 也让事件发射在干净的位置收尾。计入 [AudioTimeline.total]，但不进 WAV 数据。
  static const double kTailPaddingMs = 80;

  /// 交替对比的段数：错→对→错→对（架构 §1.3.1）。
  static const int kComparisonSegments = 4;

  /// 构建单条序列（旋律 / 和声，按 [AudioSequenceSpec.direction]）。
  static SequenceRender build(AudioSequenceSpec spec) {
    const int sr = AppConfig.sampleRate;
    final _SpecRender composed = _composeSpec(spec, sr);
    final List<AudioTimelineMark> marks = <AudioTimelineMark>[
      const AudioTimelineMark(
        at: Duration.zero,
        type: AudioEventType.sequenceStart,
        noteIndex: -1,
        segmentIndex: 0,
      ),
      ...composed.marks,
      _mark(
        AudioEventType.sequenceEnd,
        composed.pcm.length,
        sr,
        noteIndex: -1,
        segmentIndex: 0,
      ),
    ];
    final Uint8List wav = WavEncoder.encodeMono16(composed.pcm, sr);
    final Duration total = _atForSample(composed.pcm.length + _tailSamples(sr), sr);
    return SequenceRender(
      wav: wav,
      timeline: AudioTimeline(total: total, marks: marks),
    );
  }

  /// 构建交替对比序列：把 [specs] 交替成 4 段（错→对→错→对）渲染进**一个**缓冲区。
  ///
  /// 每段间留 [gap] 静音。事件带 `segmentIndex 0..3`（架构 §1.3.1）。
  static SequenceRender buildComparison(
    List<AudioSequenceSpec> specs,
    Duration gap,
  ) {
    assert(specs.isNotEmpty, 'buildComparison 至少需要一个 spec');
    const int sr = AppConfig.sampleRate;
    final int gapSamples = (gap.inMilliseconds * sr / 1000).round();

    final List<Float32List> parts = <Float32List>[];
    final List<AudioTimelineMark> marks = <AudioTimelineMark>[
      const AudioTimelineMark(
        at: Duration.zero,
        type: AudioEventType.sequenceStart,
        noteIndex: -1,
        segmentIndex: 0,
      ),
    ];
    int cursor = 0;
    for (int seg = 0; seg < kComparisonSegments; seg++) {
      final AudioSequenceSpec spec = specs[seg % specs.length];
      final _SpecRender composed = _composeSpec(spec, sr);
      marks.add(
        AudioTimelineMark(
          at: _atForSample(cursor, sr),
          type: AudioEventType.segmentStart,
          noteIndex: -1,
          segmentIndex: seg,
        ),
      );
      // 把段内 mark 平移到当前 cursor，并打上 segmentIndex。
      for (final AudioTimelineMark m in composed.marks) {
        final int sample = _sampleOf(m.at, sr);
        marks.add(
          AudioTimelineMark(
            at: _atForSample(cursor + sample, sr),
            type: m.type,
            noteIndex: m.noteIndex,
            segmentIndex: seg,
            noteDuration: m.noteDuration,
          ),
        );
      }
      parts.add(composed.pcm);
      cursor += composed.pcm.length;
      if (seg < kComparisonSegments - 1) {
        parts.add(_zeros(gapSamples));
        cursor += gapSamples;
      }
    }
    final Float32List pcm = _concatAll(parts);
    marks.add(
      _mark(
        AudioEventType.sequenceEnd,
        pcm.length,
        sr,
        noteIndex: -1,
        segmentIndex: kComparisonSegments - 1,
      ),
    );
    final Uint8List wav = WavEncoder.encodeMono16(pcm, sr);
    final Duration total = _atForSample(pcm.length + _tailSamples(sr), sr);
    return SequenceRender(
      wav: wav,
      timeline: AudioTimeline(total: total, marks: marks),
    );
  }

  // ---------------------------------------------------------------------------
  // 内部：单 spec 渲染
  // ---------------------------------------------------------------------------

  /// 渲染单个 spec 的 PCM 与段内 mark（mark 的 `at` 以该 spec 起点为 0）。
  static _SpecRender _composeSpec(AudioSequenceSpec spec, int sr) {
    final int noteMs = spec.noteDuration.inMilliseconds;
    final int gapMs = spec.noteGap.inMilliseconds;
    final Float32List root = PcmSynthesizer.renderNote(
      spec.rootMidiNote,
      spec.timbre,
      noteMs,
      sr,
    );
    final Float32List target = PcmSynthesizer.renderNote(
      spec.targetMidiNote,
      spec.timbre,
      noteMs,
      sr,
    );

    switch (spec.direction) {
      case PlaybackDirection.harmonic:
        final int noteSamples = root.length;
        return _SpecRender(
          pcm: _mixHarmonic(root, target),
          marks: <AudioTimelineMark>[
            _mark(
              AudioEventType.noteStart,
              0,
              sr,
              noteIndex: -1,
              segmentIndex: 0,
              noteDuration: spec.noteDuration,
                          ),
            _mark(
              AudioEventType.noteEnd,
              noteSamples,
              sr,
              noteIndex: -1,
              segmentIndex: 0,
              noteDuration: spec.noteDuration,
                          ),
          ],
        );
      case PlaybackDirection.ascending:
        final _MelodyRender r = _concatMelody(root, target, gapMs, sr, spec);
        return _SpecRender(pcm: r.pcm, marks: r.marks);
      case PlaybackDirection.descending:
        // 下行：高音（目标）先响 → target 作为第一个音传入。
        final _MelodyRender r = _concatMelody(target, root, gapMs, sr, spec);
        // 交换 noteIndex：段内第一音（target）记 1，第二音（root）记 0。
        final List<AudioTimelineMark> swapped = r.marks
            .map(
              (AudioTimelineMark m) => AudioTimelineMark(
                at: m.at,
                type: m.type,
                noteIndex: m.noteIndex == 0
                    ? 1
                    : (m.noteIndex == 1 ? 0 : -1),
                segmentIndex: 0,
                noteDuration: m.noteDuration,
              ),
            )
            .toList();
        return _SpecRender(pcm: r.pcm, marks: swapped);
    }
  }

  /// 旋律：第一音 + 间隔静音 + 第二音，拼接成一个 PCM。
  static _MelodyRender _concatMelody(
    Float32List first,
    Float32List second,
    int gapMs,
    int sr,
    AudioSequenceSpec spec,
  ) {
    final int noteSamples = first.length;
    final int gapSamples = (gapMs * sr / 1000).round();
    final Float32List pcm =
        Float32List(noteSamples + gapSamples + noteSamples);
    pcm.setRange(0, noteSamples, first);
    // 间隔部分保持默认 0（静音）。
    pcm.setRange(
      noteSamples + gapSamples,
      noteSamples + gapSamples + noteSamples,
      second,
    );
    final List<AudioTimelineMark> marks = <AudioTimelineMark>[
      _mark(
        AudioEventType.noteStart,
        0,
        sr,
        noteIndex: 0,
        segmentIndex: 0,
        noteDuration: spec.noteDuration,
              ),
      _mark(
        AudioEventType.noteEnd,
        noteSamples,
        sr,
        noteIndex: 0,
        segmentIndex: 0,
        noteDuration: spec.noteDuration,
              ),
      _mark(
        AudioEventType.noteStart,
        noteSamples + gapSamples,
        sr,
        noteIndex: 1,
        segmentIndex: 0,
        noteDuration: spec.noteDuration,
              ),
      _mark(
        AudioEventType.noteEnd,
        noteSamples + gapSamples + noteSamples,
        sr,
        noteIndex: 1,
        segmentIndex: 0,
        noteDuration: spec.noteDuration,
              ),
    ];
    return _MelodyRender(pcm: pcm, marks: marks);
  }

  /// 和声：两音逐样本相加 + 软限幅（架构 §5.5）。kVoiceGain=0.22 已保证和 ≤ 0.44。
  static Float32List _mixHarmonic(Float32List a, Float32List b) {
    final int n = a.length < b.length ? a.length : b.length;
    final Float32List out = Float32List(n);
    for (int i = 0; i < n; i++) {
      out[i] = Normalizer.softLimit(a[i] + b[i]);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // 小工具
  // ---------------------------------------------------------------------------

  /// 由样本下标反算 Duration（整数除法，保证「样本→时刻→样本」往返 0 误差）。
  static Duration _atForSample(int sample, int sr) =>
      Duration(microseconds: (sample * 1000000) ~/ sr);

  /// 由 Duration 反算样本下标（与 [_atForSample] 互逆，误差 0 样本）。
  static int _sampleOf(Duration at, int sr) =>
      (at.inMicroseconds * sr / 1000000).round();

  /// 尾部 padding 的样本数。
  static int _tailSamples(int sr) =>
      (kTailPaddingMs * sr / 1000).round();

  /// 全零 PCM（间隔 / 段间静音）。
  static Float32List _zeros(int n) => Float32List(n);

  /// 拼接多个 PCM 段。
  static Float32List _concatAll(List<Float32List> parts) {
    int total = 0;
    for (final Float32List p in parts) {
      total += p.length;
    }
    final Float32List out = Float32List(total);
    int off = 0;
    for (final Float32List p in parts) {
      out.setRange(off, off + p.length, p);
      off += p.length;
    }
    return out;
  }

  /// mark 构造助手。
  static AudioTimelineMark _mark(
    AudioEventType type,
    int sample,
    int sr, {
    required int noteIndex,
    required int segmentIndex,
    Duration? noteDuration,
  }) {
    return AudioTimelineMark(
      at: _atForSample(sample, sr),
      type: type,
      noteIndex: noteIndex,
      segmentIndex: segmentIndex,
      noteDuration: noteDuration ?? Duration.zero,
    );
  }
}

/// 单 spec 渲染的中间结果（PCM + 段内 mark）。
class _SpecRender {
  const _SpecRender({required this.pcm, required this.marks});
  final Float32List pcm;
  final List<AudioTimelineMark> marks;
}

/// 旋律渲染的中间结果。
class _MelodyRender {
  const _MelodyRender({required this.pcm, required this.marks});
  final Float32List pcm;
  final List<AudioTimelineMark> marks;
}
