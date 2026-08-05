import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 13 种音程的唯一标识（原规范第四章：一个八度以内 0–12 半音）。
///
/// **命名说明（与架构 §3.1 类图的偏离）**：类图里把枚举值写成 `p1 m2 M2 …`，
/// 但 Dart 的 `constant_identifier_names` lint 要求枚举常量用 lowerCamelCase，
/// 项目 CI 要求 0 issue，因此这里用语义化的英文全名。**落盘契约完全不受影响**：
/// 持久化用的仍然是 `storageId`（`'P1'` / `'m2'` / `'M2'` …），与类图一致。
///
/// 半音数即枚举顺序，`IntervalId.values[n].semitones == n` 恒成立，但代码里
/// 不要依赖 `index`，一律用 [semitones] / [fromSemitones]。
enum IntervalId {
  /// 纯一度，0 半音。
  perfectUnison(0, 'P1'),

  /// 小二度，1 半音。
  minorSecond(1, 'm2'),

  /// 大二度，2 半音。
  majorSecond(2, 'M2'),

  /// 小三度，3 半音。
  minorThird(3, 'm3'),

  /// 大三度，4 半音。
  majorThird(4, 'M3'),

  /// 纯四度，5 半音。
  perfectFourth(5, 'P4'),

  /// 增四度 / 减五度（三全音），6 半音。
  tritone(6, 'TT'),

  /// 纯五度，7 半音。
  perfectFifth(7, 'P5'),

  /// 小六度，8 半音。
  minorSixth(8, 'm6'),

  /// 大六度，9 半音。
  majorSixth(9, 'M6'),

  /// 小七度，10 半音。
  minorSeventh(10, 'm7'),

  /// 大七度，11 半音。
  majorSeventh(11, 'M7'),

  /// 纯八度，12 半音。
  perfectOctave(12, 'P8');

  const IntervalId(this.semitones, this.storageId);

  /// 半音数，`[0, 12]`。
  final int semitones;

  /// 落盘用稳定字符串（架构 §8.6）。
  final String storageId;

  /// 半音数上限。
  static const int maxSemitones = 12;

  /// 未知值降级目标。选纯一度是因为它是「最不可能被误判为别的音程」的锚点，
  /// 一旦数据里出现它，异常在报表上会非常显眼。
  static const IntervalId defaultValue = IntervalId.perfectUnison;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]（前向兼容）。
  static IntervalId fromStorageId(Object? raw) => decodeEnumByStorageId(
        IntervalId.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );

  /// 由 `storageId` 解码，未知值返回 `null`。
  ///
  /// 与 [fromStorageId] 的分工：解析落盘数据用 [fromStorageId]（要降级），
  /// 校验用户输入/外部输入用本方法（要能区分「没有」）。
  static IntervalId? tryFromStorageId(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final value in IntervalId.values) {
      if (value.storageId == raw) {
        return value;
      }
    }
    return null;
  }

  /// 由半音数取音程。越界抛 [RangeError]（领域层的编程错误应当在测试中暴露，
  /// 架构 §8.2）。
  static IntervalId fromSemitones(int semitones) {
    if (semitones < 0 || semitones > maxSemitones) {
      throw RangeError.range(semitones, 0, maxSemitones, 'semitones');
    }
    return IntervalId.values[semitones];
  }

  /// 由半音数取音程，越界返回 `null`。
  static IntervalId? tryFromSemitones(int semitones) =>
      semitones < 0 || semitones > maxSemitones
          ? null
          : IntervalId.values[semitones];

  /// 与 [other] 的半音距离（绝对值）。混淆矩阵排序的次级键。
  int semitoneDistanceTo(IntervalId other) =>
      (semitones - other.semitones).abs();
}
