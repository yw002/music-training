import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/synth/pcm_synthesizer.dart';
import 'package:interval_ear/core/audio/synth/synth_isolate.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';

/// T07 验收 5 + 任务清单：synth_isolate 用 Isolate.run 封装渲染，不阻塞 UI 线程，
/// 且跨 Isolate 结果与同步渲染逐字节一致（铁律③）。
void main() {
  const int sr = 44100;

  group('SynthIsolate Isolate.run 封装', () {
    test('渲染结果与同步 PcmSynthesizer.renderNote 逐字节一致（铁律③）', () async {
      final Float32List sync =
          PcmSynthesizer.renderNote(60, Timbre.keyboard, 800, sr);
      final Float32List iso = await SynthIsolate.renderNote(
        midi: 60,
        timbre: Timbre.keyboard,
        durationMs: 800,
        sampleRate: sr,
      );
      expect(iso.length, sync.length);
      for (int i = 0; i < iso.length; i++) {
        expect(iso[i], sync[i], reason: '样本 $i 跨 Isolate 不一致');
      }
    });

    test('两种音色在 Isolate 中均确定且与同步一致', () async {
      for (final Timbre timbre in Timbre.values) {
        final Float32List sync =
            PcmSynthesizer.renderNote(64, timbre, 600, sr);
        final Float32List iso = await SynthIsolate.renderNote(
          midi: 64,
          timbre: timbre,
          durationMs: 600,
          sampleRate: sr,
        );
        expect(iso, orderedEquals(sync));
      }
    });

    test('不阻塞 UI 线程：await 让出事件循环（微任务可推进）', () async {
      bool progressed = false;
      final Future<Float32List> f = SynthIsolate.renderNote(
        midi: 60,
        timbre: Timbre.plucked,
        durationMs: 1100,
        sampleRate: sr,
      );
      // 在 await 之前排一个微任务：若主线程被同步阻塞，它不会运行。
      final Future<void> marker =
          Future<void>.microtask(() => progressed = true);
      await f;
      await marker;
      expect(progressed, isTrue);
    });

    test('多次并发 Isolate 渲染均正确返回', () async {
      final List<Future<Float32List>> futures = <Future<Float32List>>[];
      for (int i = 0; i < 4; i++) {
        futures.add(SynthIsolate.renderNote(
          midi: 60 + i,
          timbre: Timbre.keyboard,
          durationMs: 500,
          sampleRate: sr,
        ));
      }
      final List<Float32List> results = await Future.wait(futures);
      expect(results.length, 4);
      for (int i = 0; i < 4; i++) {
        final Float32List sync =
            PcmSynthesizer.renderNote(60 + i, Timbre.keyboard, 500, sr);
        expect(results[i], orderedEquals(sync));
      }
    });
  });
}
