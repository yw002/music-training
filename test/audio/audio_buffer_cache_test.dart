import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/cache/audio_buffer_cache.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';

/// T08 验收 4/5 + 任务清单：三级缓存 LRU 淘汰、命中率、key 唯一性、
/// 缓存键不含题目 ID、容量上限取自 app_config。
AudioSequenceSpec _spec(int root, int target, Timbre timbre) =>
    AudioSequenceSpec(
      rootMidiNote: root,
      targetMidiNote: target,
      direction: PlaybackDirection.ascending,
      timbre: timbre,
    );

void main() {
  group('AudioBufferCache L2 序列缓存 · LRU 淘汰与命中率', () {
    test('超出容量淘汰最久未用；命中不重新合成（buildCount）', () {
      final AudioBufferCache cache = AudioBufferCache(
        noteCapacity: 8,
        sequenceCapacity: 2,
        loadedCapacity: 8,
      );
      final AudioSequenceSpec a = _spec(60, 64, Timbre.keyboard);
      final AudioSequenceSpec b = _spec(62, 65, Timbre.keyboard);
      final AudioSequenceSpec c = _spec(64, 67, Timbre.keyboard);

      cache.getOrBuild(a);
      cache.getOrBuild(b);
      cache.getOrBuild(c); // 淘汰 a。
      expect(cache.buildCount, 3);

      // a 已淘汰 → 重新合成；此时 b 被挤掉（容量 2）。
      cache.getOrBuild(a);
      expect(cache.buildCount, 4);

      // b 已不在缓存 → 再次重建（非命中）。
      final r1 = cache.getOrBuild(b);
      final r2 = cache.getOrBuild(b);
      expect(identical(r1, r2), isTrue); // 连续取同一键命中同一实例。
      expect(cache.buildCount, 5);
    });

    test('容量上限取自 app_config（默认 = AppConfig.sequenceCacheCapacity）', () {
      final AudioBufferCache cache = AudioBufferCache(); // 默认容量
      final List<AudioSequenceSpec> specs = <AudioSequenceSpec>[
        for (int i = 0; i < 25; i++) _spec(60 + i, 64 + i, Timbre.keyboard),
      ];
      for (int i = 0; i < 24; i++) {
        cache.getOrBuild(specs[i]);
      }
      expect(cache.buildCount, 24); // 24 个不同键，容量恰好 24，无淘汰。

      // specs[23] 仍在缓存（容量 24，未超）；连续取命中同一实例、不重建。
      final r1 = cache.getOrBuild(specs[23]);
      final r2 = cache.getOrBuild(specs[23]);
      expect(identical(r1, r2), isTrue);
      expect(cache.buildCount, 24);

      // 第 25 个不同键触发 LRU 淘汰最久未用者 specs[0]（specs[23] 刚被访问过，
      // 故 specs[0] 是最久未用）。buildCount +1。
      cache.getOrBuild(specs[24]);
      expect(cache.buildCount, 25);

      // specs[0] 已被淘汰 → 重建，buildCount +1。
      cache.getOrBuild(specs[0]);
      expect(cache.buildCount, 26);

      // 验证默认序列容量确实等于 app_config。
      expect(AppConfig.sequenceCacheCapacity, 24);
    });
  });

  group('AudioBufferCache L1 单音缓存', () {
    test('同 midi/音色/时长命中同一实例（identical）', () {
      final AudioBufferCache cache = AudioBufferCache(
        noteCapacity: 4,
        sequenceCapacity: 8,
        loadedCapacity: 8,
      );
      final Float32List a = cache.getNotePcm(60, Timbre.keyboard, 800);
      final Float32List b = cache.getNotePcm(60, Timbre.keyboard, 800);
      expect(identical(a, b), isTrue);
    });

    test('L1 超出容量淘汰最久未用', () {
      final AudioBufferCache cache = AudioBufferCache(
        noteCapacity: 2,
        sequenceCapacity: 8,
        loadedCapacity: 8,
      );
      final Float32List a = cache.getNotePcm(60, Timbre.keyboard, 800);
      cache.getNotePcm(61, Timbre.keyboard, 800);
      cache.getNotePcm(62, Timbre.keyboard, 800); // 淘汰 60。
      final Float32List a2 = cache.getNotePcm(60, Timbre.keyboard, 800);
      expect(identical(a, a2), isFalse); // 重新合成，非同一实例。
    });

    test('不同音色使用不同键（不串音）', () {
      final AudioBufferCache cache = AudioBufferCache(
        noteCapacity: 8,
        sequenceCapacity: 8,
        loadedCapacity: 8,
      );
      final Float32List k = cache.getNotePcm(60, Timbre.keyboard, 800);
      final Float32List p = cache.getNotePcm(60, Timbre.plucked, 800);
      expect(identical(k, p), isFalse);
    });
  });

  group('AudioBufferCache 缓存键不含题目 ID（T08 验收 5）', () {
    test('AudioSequenceSpec.cacheKey 仅含音程/根音/音色/时长，无题目 ID', () {
      final AudioSequenceSpec spec = _spec(60, 64, Timbre.keyboard);
      final String key = spec.cacheKey();
      // 格式断言。
      expect(key, 'r60-t64-asc-kbd-1100-180-1.000');
      // 防泄露护栏：键里绝不能出现题目 id 字样。
      expect(key.toLowerCase().contains('question'), isFalse);
      expect(key.toLowerCase().contains('qid'), isFalse);
      expect(key.contains('Question'), isFalse);
    });

    test('同音程同根音同音色命中同一键；改根音得到不同键', () {
      final AudioSequenceSpec a = _spec(60, 64, Timbre.keyboard);
      final AudioSequenceSpec b = _spec(60, 64, Timbre.keyboard);
      final AudioSequenceSpec c = _spec(61, 64, Timbre.keyboard);
      expect(a.cacheKey(), b.cacheKey()); // 相同参数 → 同一键
      expect(a.cacheKey(), isNot(c.cacheKey())); // 不同根音 → 不同键
    });

    test('copyWith 产生的等价规格产生相同键（键与题目身份无关）', () {
      final AudioSequenceSpec a = _spec(60, 64, Timbre.keyboard);
      final AudioSequenceSpec b =
          a.copyWith(direction: PlaybackDirection.ascending);
      expect(a.cacheKey(), b.cacheKey());
    });

    test('withInterval 在下行模式生成低于根音的目标音', () {
      const spec = AudioSequenceSpec(
        rootMidiNote: 72,
        targetMidiNote: 71,
        direction: PlaybackDirection.descending,
        timbre: Timbre.keyboard,
      );
      final changed = spec.withInterval(IntervalId.perfectFifth);
      expect(changed.targetMidiNote, 65);
    });
  });
}
