/// 训练领域的全部枚举（架构 §3.1）。
///
/// **落盘契约（架构 §8.6）**：所有枚举一律以稳定的 `storageId` 字符串持久化，
/// 禁止使用 `enum.index`——否则将来在枚举中间插入一个值就会让历史数据整体错位。
///
/// **前向兼容（T04 验收 6）**：`fromStorageId` 遇到未知字符串时降级为该枚举的
/// `defaultValue`，而不是抛异常。理由：低版本 App 读到高版本写入的数据时，
/// 应当「尽量把能读的读出来」，而不是整个文件解析失败触发重建。
///
/// **文案（架构 §8.5 规则 3）**：这里刻意**不**提供 `labelZh`。除音程名称外，
/// 面向用户的中文一律走 `AppStrings`（`SettingsStrings.directionAscending` 等），
/// domain 层保持纯数据、零文案。
library;

/// 把 `storageId` 解码回枚举值，未知值降级为 [fallback]。
///
/// 之所以做成顶层泛型函数而不是每个枚举各写一遍 `switch`：新增枚举值时不会
/// 有人忘记补 `case`，解码行为在全项目内严格一致。
T decodeEnumByStorageId<T>(
  List<T> values,
  String Function(T value) storageIdOf,
  Object? raw,
  T fallback,
) {
  if (raw is! String || raw.isEmpty) {
    return fallback;
  }
  for (final value in values) {
    if (storageIdOf(value) == raw) {
      return value;
    }
  }
  return fallback;
}

/// 单题实际采用的播放方向。
///
/// 与 [DirectionMode] 的区别：[DirectionMode] 是**用户配置**（可以是「随机混合」），
/// [PlaybackDirection] 是**出题时已经掷过骰子的结果**，永远是三个具体方向之一。
/// 把这两者分成两个枚举，可以让 `IntervalQuestion` 在类型上就不可能持有
/// 「随机混合」这种未决状态。
enum PlaybackDirection {
  /// 先低后高。
  ascending('asc'),

  /// 先高后低。
  descending('desc'),

  /// 两音同时发声。
  harmonic('harm');

  const PlaybackDirection(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const PlaybackDirection defaultValue = PlaybackDirection.ascending;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static PlaybackDirection fromStorageId(Object? raw) => decodeEnumByStorageId(
        PlaybackDirection.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}

/// 用户配置的播放方向策略。
enum DirectionMode {
  /// 全部上行。
  ascending('asc'),

  /// 全部下行。
  descending('desc'),

  /// 全部和声。
  harmonic('harm'),

  /// 每题在上行/下行/和声中随机。
  randomMixed('mixed');

  const DirectionMode(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const DirectionMode defaultValue = DirectionMode.ascending;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static DirectionMode fromStorageId(Object? raw) => decodeEnumByStorageId(
        DirectionMode.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );

  /// 非随机模式对应的确定方向；[randomMixed] 返回 `null`（需要掷骰子）。
  PlaybackDirection? get fixedDirection => switch (this) {
        DirectionMode.ascending => PlaybackDirection.ascending,
        DirectionMode.descending => PlaybackDirection.descending,
        DirectionMode.harmonic => PlaybackDirection.harmonic,
        DirectionMode.randomMixed => null,
      };
}

/// 根音生成策略。
enum RootMode {
  /// 固定 C4。
  fixed('fixed'),

  /// 有限随机：根音限定在 C4–B4，便于初学者建立参照。
  limitedRandom('limited'),

  /// 完全随机：在「防泄露统一安全窗口」内均匀取值（算法见 §5.3）。
  fullRandom('full');

  const RootMode(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const RootMode defaultValue = RootMode.limitedRandom;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static RootMode fromStorageId(Object? raw) => decodeEnumByStorageId(
        RootMode.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}

/// 单题实际使用的音色（已掷过骰子的结果）。
enum Timbre {
  /// 合成键盘：多谐波 + 逐谐波指数衰减。
  keyboard('kbd'),

  /// 合成拨弦：Karplus–Strong。
  plucked('pluck');

  const Timbre(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const Timbre defaultValue = Timbre.keyboard;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static Timbre fromStorageId(Object? raw) => decodeEnumByStorageId(
        Timbre.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}

/// 用户配置的音色策略。
enum TimbreMode {
  /// 固定合成键盘。
  keyboard('kbd'),

  /// 固定合成拨弦。
  plucked('pluck'),

  /// 每题随机。
  random('random');

  const TimbreMode(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const TimbreMode defaultValue = TimbreMode.keyboard;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static TimbreMode fromStorageId(Object? raw) => decodeEnumByStorageId(
        TimbreMode.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );

  /// 非随机模式对应的确定音色；[random] 返回 `null`。
  Timbre? get fixedTimbre => switch (this) {
        TimbreMode.keyboard => Timbre.keyboard,
        TimbreMode.plucked => Timbre.plucked,
        TimbreMode.random => null,
      };
}

/// 答题选项的构成策略。
enum AnswerMode {
  /// 13 个音程全部列出（固定网格）。
  allIntervals('all'),

  /// 只列出本次训练启用的音程。
  enabledOnly('enabled'),

  /// 二选一强化训练。
  binary('binary');

  const AnswerMode(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const AnswerMode defaultValue = AnswerMode.enabledOnly;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static AnswerMode fromStorageId(Object? raw) => decodeEnumByStorageId(
        AnswerMode.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}

/// 一次播放请求的形态。
///
/// 与 [PlaybackDirection] 正交：方向决定「哪两个音、谁先谁后」，[PlayMode]
/// 决定「播一遍，还是把两个候选音程交替播出来做 A/B 对比」（答错后的对比播放）。
enum PlayMode {
  /// 普通播放：按题目方向播一遍。
  single('single'),

  /// 交替对比：正确音程与用户所选音程各播一遍，中间留静音间隔。
  compare('compare');

  const PlayMode(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const PlayMode defaultValue = PlayMode.single;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static PlayMode fromStorageId(Object? raw) => decodeEnumByStorageId(
        PlayMode.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}

/// 训练模式（决定组卷策略与结算口径）。
enum TrainingMode {
  /// 今日推荐：自适应加权组卷。
  daily('daily'),

  /// 自由训练：完全按用户配置。
  free('free'),

  /// 二选一强化。
  binaryDrill('binary'),

  /// 答错后即时插入的加练题。
  extraDrill('extra');

  const TrainingMode(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const TrainingMode defaultValue = TrainingMode.daily;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static TrainingMode fromStorageId(Object? raw) => decodeEnumByStorageId(
        TrainingMode.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}

/// 题目来源桶。用于「这道题为什么会出现」的可解释性与事后分析。
enum QuestionBucket {
  /// 薄弱音程 / 薄弱音程对。
  weakPair('weak'),

  /// 近期答错过的音程。
  recentWrong('recent'),

  /// 间隔复习（已较熟练，防遗忘）。
  spacedReview('spaced'),

  /// 随机抽查（已掌握，抽样验证）。
  randomProbe('probe'),

  /// 热身题。热身段单独归桶，避免「还没进入状态」的失误污染薄弱判定。
  warmUp('warmup');

  const QuestionBucket(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。
  static const QuestionBucket defaultValue = QuestionBucket.randomProbe;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static QuestionBucket fromStorageId(Object? raw) => decodeEnumByStorageId(
        QuestionBucket.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}

/// 掌握度分档（架构 §5.1 的分桶结果，§5.2 的组卷输入）。
///
/// 阈值本身不写在这里而是放在 `algorithm_constants.dart`，由
/// `MasteryCalculator.bucketOf` 负责映射：枚举描述「有哪几档」，
/// 常量描述「档与档的边界在哪」，调参时只动后者。
///
/// 声明顺序即由弱到强，因此 `index` 可直接用于排序。
enum MasteryBucket {
  /// 薄弱：需要重点攻坚。
  weak('weak'),

  /// 一般：还需巩固。
  medium('medium'),

  /// 良好：偶尔复习即可。
  strong('strong'),

  /// 已掌握：只做低频抽查防遗忘。
  mastered('mastered');

  const MasteryBucket(this.storageId);

  /// 落盘用稳定字符串。
  final String storageId;

  /// 未知值降级目标。新用户零历史时所有音程都在 weak，降级到 weak 最安全。
  static const MasteryBucket defaultValue = MasteryBucket.weak;

  /// 由 `storageId` 解码，未知值降级为 [defaultValue]。
  static MasteryBucket fromStorageId(Object? raw) => decodeEnumByStorageId(
        MasteryBucket.values,
        (v) => v.storageId,
        raw,
        defaultValue,
      );
}
