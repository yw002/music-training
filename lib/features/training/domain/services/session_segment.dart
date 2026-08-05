import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 一组训练里的「分段」（架构 §5.7）。
///
/// 组卷不是 20 道同质的题，而是三段式：
/// 1. **热身段**（前 [kWarmUpSegmentRatio]）：题型简单、方向/音色固定，让用户
///    进入状态；其失误不该污染「薄弱判定」。
/// 2. **弱项攻坚段**（累计到 [kWeakFocusSegmentRatio]）：集中弱项，最大化增益。
/// 3. **混合段**（其余）：全桶按配额混合，做综合检验。
///
/// 分段是**纯索引区间**——题目本身已经在 [SessionPlan.questions] 里，
/// 段只描述「[startIndex, endIndex) 这几道属于哪一类」，UI 据此切换引导语与
/// 是否允许重播等策略，不出题。
class SessionSegment {
  /// 创建分段。
  const SessionSegment({
    required this.type,
    required this.startIndex,
    required this.endIndex,
  }) : intervalCount = endIndex - startIndex;

  /// 分段类型。
  final SessionSegmentType type;

  /// 在 [SessionPlan.questions] 中的起始下标（含）。
  final int startIndex;

  /// 结束下标（不含）。
  final int endIndex;

  /// 本段题目数。
  final int intervalCount;

  /// 是否为空段。
  bool get isEmpty => intervalCount <= 0;

  /// 覆盖的下标区间。
  Iterable<int> get indices => <int>[
        for (var i = startIndex; i < endIndex; i++) i,
      ];

  /// 本段涉及的来源桶（便于「热身段全部归 warmUp 桶」）。
  QuestionBucket get bucket => switch (type) {
        SessionSegmentType.warmUp => QuestionBucket.warmUp,
        SessionSegmentType.weakFocus => QuestionBucket.weakPair,
        SessionSegmentType.mixed => QuestionBucket.randomProbe,
      };

  @override
  String toString() => 'SessionSegment($type, '
      '[$startIndex, $endIndex), $intervalCount 题)';
}

/// 分段类型（按 §5.7 的顺序）。
enum SessionSegmentType {
  /// 热身段。
  warmUp,

  /// 弱项攻坚段。
  weakFocus,

  /// 混合段。
  mixed;
}
