import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_timeline.dart';
import 'package:interval_ear/core/audio/synth/sequence_builder.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// T08 验收 2/3 + 任务清单：mark 顺序、和声 noteIndex=-1、tailPadding。
void main() {
  const int sr = 44100;

  group('AudioTimeline mark 顺序', () {
    test('旋律 mark 按 at 严格升序', () {
      const AudioSequenceSpec spec = AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
      );
      final AudioTimeline tl = SequenceBuilder.build(spec).timeline;
      for (int i = 1; i < tl.marks.length; i++) {
        expect(tl.marks[i].at, greaterThanOrEqualTo(tl.marks[i - 1].at));
      }
      // 首末必须是序列起/止。
      expect(tl.marks.first.type, AudioEventType.sequenceStart);
      expect(tl.marks.last.type, AudioEventType.sequenceEnd);
    });

    test('nextMarkIndex 返回晚于 position 的下一个下标', () {
      final AudioTimeline tl =
          SequenceBuilder.build(const AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
      )).timeline;
      final Duration pos = tl.marks[2].at; // 略过前两个。
      final int? idx = tl.nextMarkIndex(pos);
      expect(idx, isNotNull);
      expect(tl.marks[idx!].at, greaterThan(pos));
      // 超过最后一个 → null。
      expect(tl.nextMarkIndex(tl.total), isNull);
    });
  });

  group('AudioTimeline 和声 noteIndex=-1', () {
    test('和声的 noteStart/noteEnd noteIndex 均为 -1', () {
      final AudioTimeline tl =
          SequenceBuilder.build(const AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.harmonic,
        timbre: Timbre.keyboard,
      )).timeline;
      for (final AudioTimelineMark m in tl.marks) {
        if (m.type == AudioEventType.noteStart ||
            m.type == AudioEventType.noteEnd) {
          expect(m.noteIndex, -1);
        }
      }
    });
  });

  group('AudioTimeline tailPadding', () {
    test('总时长 = PCM 样本数 + 尾部 80ms padding（含 padding 但不进 WAV）', () {
      final SequenceRender render = SequenceBuilder.build(const AudioSequenceSpec(
        rootMidiNote: 60,
        targetMidiNote: 64,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
      ));
      final int pcmSamples = (render.wav.length - 44) ~/ 2;
      final int tailSamples =
          (SequenceBuilder.kTailPaddingMs * sr / 1000).round();
      // total 对应的样本数应为 pcmSamples + tailSamples。
      final int totalSamples =
          (render.timeline.total.inMicroseconds * sr / 1000000).round();
      expect(totalSamples, pcmSamples + tailSamples);
      // tailPadding 确实存在：total 严格大于纯 PCM 时长。
      expect(render.timeline.total,
          greaterThan(Duration(microseconds: pcmSamples * 1000000 ~/ sr)));
    });
  });
}
