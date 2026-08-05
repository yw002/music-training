import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/synth/normalizer.dart';
import 'package:interval_ear/core/audio/synth/pcm_synthesizer.dart';
import 'package:interval_ear/core/audio/synth/sequence_builder.dart';
import 'package:interval_ear/core/audio/synth/wav_encoder.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// T08 验收 1/2/3 + 任务清单：三种序列（旋律/和声/交替对比）、总样本数、
/// mark 顺序、以及「Timeline 与波形一致」（解码 WAV 与重建 PCM 逐样本核对）。
Float32List _decodeWav(Uint8List wav) {
  final int dataSize = wav.length - WavEncoder.headerBytes;
  final int n = dataSize ~/ 2;
  final Float32List out = Float32List(n);
  final ByteData bd = ByteData.sublistView(wav);
  for (int i = 0; i < n; i++) {
    final int s = bd.getInt16(WavEncoder.headerBytes + i * 2, Endian.little);
    out[i] = s / 32767.0;
  }
  return out;
}

int _sampleOf(Duration at, int sr) =>
    (at.inMicroseconds * sr / 1000000).round();

void main() {
  const int sr = 44100;
  const int noteMs = 1100;
  const int gapMs = 180;

  group('SequenceBuilder 旋律（T08 验收 1/3）', () {
    test('总长度 = round(44100 × (1.1 + 0.18 + 1.1)) + 尾部 80ms', () {
      const AudioSequenceSpec spec = AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
        noteDuration: Duration(milliseconds: noteMs),
        noteGap: Duration(milliseconds: gapMs),
      );
      final SequenceRender render = SequenceBuilder.build(spec);

      final int noteSamples = (noteMs * sr / 1000).round();
      final int gapSamples = (gapMs * sr / 1000).round();
      final int pcmLen = noteSamples + gapSamples + noteSamples;
      final int tailSamples = (SequenceBuilder.kTailPaddingMs * sr / 1000).round();

      expect(render.wav.length, WavEncoder.headerBytes + pcmLen * 2);
      // 总时长含尾部 padding。
      expect(
        render.timeline.total,
        Duration(microseconds: ((pcmLen + tailSamples) * 1000000 / sr).round()),
      );
      // 任务清单给出的精确值。
      expect(render.timeline.total, const Duration(microseconds: 2460000));
    });

    test('Timeline mark 顺序与波形一致（解码 WAV 核对旋律拼接）', () {
      const AudioSequenceSpec spec = AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
        noteDuration: Duration(milliseconds: noteMs),
        noteGap: Duration(milliseconds: gapMs),
      );
      final SequenceRender render = SequenceBuilder.build(spec);
      final Float32List pcm = _decodeWav(render.wav);

      final int noteSamples = (noteMs * sr / 1000).round();
      final int gapSamples = (gapMs * sr / 1000).round();

      // mark 反向算出样本下标，与拼接边界一致（误差 0 样本）。
      final List<AudioTimelineMark> marks = render.timeline.marks;
      expect(marks.first.type, AudioEventType.sequenceStart);
      expect(_sampleOf(marks[1].at, sr), 0); // noteStart(0)
      expect(marks[1].noteIndex, 0);
      expect(_sampleOf(marks[2].at, sr), noteSamples); // noteEnd(0)
      expect(_sampleOf(marks[3].at, sr), noteSamples + gapSamples); // noteStart(1)
      expect(marks[3].noteIndex, 1);
      expect(_sampleOf(marks[4].at, sr), noteSamples + gapSamples + noteSamples);
      expect(marks.last.type, AudioEventType.sequenceEnd);

      // 解码后的 PCM 应等于 root + 静音间隔 + target 的拼接。
      final Float32List root =
          PcmSynthesizer.renderNote(60, Timbre.keyboard, noteMs, sr);
      final Float32List target =
          PcmSynthesizer.renderNote(64, Timbre.keyboard, noteMs, sr);
      for (int i = 0; i < noteSamples; i++) {
        expect(pcm[i], closeTo(root[i], 1e-4));
        expect(pcm[noteSamples + gapSamples + i], closeTo(target[i], 1e-4));
      }
      // 间隔段应为静音（≈0）。
      for (int i = noteSamples; i < noteSamples + gapSamples; i++) {
        expect(pcm[i].abs(), lessThan(1e-4));
      }
    });
  });

  group('SequenceBuilder 和声（T08 验收 1：两音同起）', () {
    test('两音同相、noteIndex=-1、混音等于 softLimit(root+target)', () {
      const AudioSequenceSpec spec = AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.harmonic,
        timbre: Timbre.keyboard,
        noteDuration: Duration(milliseconds: noteMs),
      );
      final SequenceRender render = SequenceBuilder.build(spec);
      final Float32List pcm = _decodeWav(render.wav);

      final int noteSamples = (noteMs * sr / 1000).round();
      expect(_sampleOf(render.timeline.marks[1].at, sr), 0); // noteStart@0
      expect(render.timeline.marks[1].noteIndex, -1); // 和声两音同响
      expect(_sampleOf(render.timeline.marks[2].at, sr), noteSamples); // noteEnd

      final Float32List root =
          PcmSynthesizer.renderNote(60, Timbre.keyboard, noteMs, sr);
      final Float32List target =
          PcmSynthesizer.renderNote(64, Timbre.keyboard, noteMs, sr);
      for (int i = 0; i < noteSamples; i++) {
        final double expected = Normalizer.softLimit(root[i] + target[i]);
        expect(pcm[i], closeTo(expected, 1e-4));
      }
    });
  });

  group('SequenceBuilder 下行（noteIndex 交换）', () {
    test('下行：先响目标（noteIndex=1），后响根音（noteIndex=0）', () {
      const AudioSequenceSpec spec = AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.descending,
        timbre: Timbre.keyboard,
        noteDuration: Duration(milliseconds: noteMs),
        noteGap: Duration(milliseconds: gapMs),
      );
      final SequenceRender render = SequenceBuilder.build(spec);
      final int noteSamples = (noteMs * sr / 1000).round();
      final int gapSamples = (gapMs * sr / 1000).round();
      final List<AudioTimelineMark> marks = render.timeline.marks;
      // 第一个 noteStart 是目标（高音先响）→ noteIndex 1。
      expect(marks[1].type, AudioEventType.noteStart);
      expect(marks[1].noteIndex, 1);
      expect(marks[3].noteIndex, 0); // 第二个 noteStart 是根音。
      expect(_sampleOf(marks[3].at, sr), noteSamples + gapSamples);
    });
  });

  group('SequenceBuilder 交替对比（T08 验收 1：错→对→错→对 4 段）', () {
    test('4 段 segmentStart，segmentIndex 0..3，且总时长正确', () {
      const AudioSequenceSpec spec = AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
        noteDuration: Duration(milliseconds: noteMs),
        noteGap: Duration(milliseconds: gapMs),
      );
      const Duration gap = Duration(milliseconds: 320);
      final SequenceRender render =
          SequenceBuilder.buildComparison(<AudioSequenceSpec>[spec], gap);
      final int noteSamples = (noteMs * sr / 1000).round();
      final int gapSamples = (gapMs * sr / 1000).round();
      final int pcmPerSeg = noteSamples + gapSamples + noteSamples;
      final int gapBetween = (320 * sr / 1000).round();

      final List<AudioTimelineMark> segStarts = render.timeline.marks
          .where((AudioTimelineMark m) => m.type == AudioEventType.segmentStart)
          .toList();
      expect(segStarts.length, SequenceBuilder.kComparisonSegments);
      for (int s = 0; s < SequenceBuilder.kComparisonSegments; s++) {
        expect(segStarts[s].segmentIndex, s);
        expect(_sampleOf(segStarts[s].at, sr), s * (pcmPerSeg + gapBetween));
      }

      // 总样本数 = 4 段 + 3 段间静音 + 尾部 80ms。
      final int tailSamples =
          (SequenceBuilder.kTailPaddingMs * sr / 1000).round();
      final int totalSamples =
          4 * pcmPerSeg + 3 * gapBetween + tailSamples;
      expect(
        render.timeline.total,
        Duration(microseconds: (totalSamples * 1000000 / sr).round()),
      );
    });
  });
}
