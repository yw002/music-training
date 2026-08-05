/// 训练算法的全部常量（架构 §5 的落点）。
///
/// **T06 验收 6：服务类中零魔法数字。** 任何出现在 `domain/services/` 里的
/// 数值都必须先在这里命名。
///
/// 与 `AppConfig` 的分工：`AppConfig` 是「跨模块的全局配置」（音域、采样率、
/// 缓存容量），本文件是「算法专属参数」。凡是 `AppConfig` 已有的值，这里一律
/// **转引用而不是抄一遍**，避免两个真相。
///
/// > ⚠️ 已知冲突：`AppConfig.kMasteryConfidenceK` / `masteryStrongThreshold`
/// > / `masteryMediumThreshold` / `masteryMinSamples` 是 T01 阶段按早期草案填的，
/// > 与架构 §5.1 的最终公式（阈值 0.50 / 0.75 / 0.90）**不一致**。
/// > 掌握度算法以本文件为准（§5 是「功能正确性的唯一裁决依据」）；
/// > `AppConfig` 里那四个常量已无人引用，应在后续清理中删除。
library;

import 'package:interval_ear/core/constants/app_config.dart';

// -----------------------------------------------------------------------------
// 音域与音高（§5.3）
// -----------------------------------------------------------------------------

/// 训练音域下界 C3。
const int kMinMidi = AppConfig.minMidi;

/// 训练音域上界 C6。
const int kMaxMidi = AppConfig.maxMidi;

/// 一个八度的半音数，同时也是本 App 支持的最大音程跨度。
const int kMaxSemitones = 12;

/// 固定根音模式使用的根音 C4。
const int kFixedRootMidi = AppConfig.fixedRootMidi;

/// 有限随机根音下界 C4。
const int kWithinOctaveRootLo = AppConfig.limitedRandomRootMin;

/// 有限随机根音上界 B4。
const int kWithinOctaveRootHi = AppConfig.limitedRandomRootMax;

/// A4 的 MIDI 号。
const int kA4Midi = AppConfig.referencePitchMidi;

/// A4 的频率（Hz）。
const double kA4Hz = AppConfig.referencePitchHz;

/// 一个八度的半音数（频率换算用，与 [kMaxSemitones] 数值相同但语义不同）。
const int kSemitonesPerOctave = 12;

// -----------------------------------------------------------------------------
// 掌握度（§5.1）
// -----------------------------------------------------------------------------

/// 置信度平滑系数 K：`confidence = n / (n + K)`。
///
/// n=5 → 0.5，n=20 → 0.8，n=45 → 0.9。这条曲线让「练 2 题全对」的音程
/// mastery 只有 0.286，仍落在 weak 桶——这正是本公式存在的意义。
const double kMasteryConfidenceK = 5.0;

/// 近期表现窗口长度：取最近 10 次作答。一组训练 20 题，取一半作为「近期」。
const int kRecentWindow = 10;

/// 近期表现在混合正确率中的权重。让进步能较快反映到组卷上，同时保留历史惯性。
const double kRecentWeight = 0.6;

/// mastery 分桶上界：低于此值为 weak。
const double kMasteryWeakMax = 0.50;

/// mastery 分桶上界：低于此值（且不低于 [kMasteryWeakMax]）为 medium。
const double kMasteryMediumMax = 0.75;

/// mastery 分桶上界：低于此值（且不低于 [kMasteryMediumMax]）为 strong。
const double kMasteryStrongMax = 0.90;

// -----------------------------------------------------------------------------
// 自适应加权组卷（§5.2）
// -----------------------------------------------------------------------------

/// weak 桶权重。
const double kBucketWeightWeak = 0.50;

/// medium 桶权重。
const double kBucketWeightMedium = 0.25;

/// strong 桶权重。
const double kBucketWeightStrong = 0.15;

/// mastered 桶权重。
const double kBucketWeightMastered = 0.10;

/// 同一音程允许连续出现的最大次数（不允许连续 3 题相同）。
const int kMaxSameIntervalRun = AppConfig.maxConsecutiveSameInterval;

/// weak 桶非空时的保底题数。
const int kWeakBucketMinQuota = 1;

// -----------------------------------------------------------------------------
// 二选一均衡与干扰项（§5.4）
// -----------------------------------------------------------------------------

/// 左右均衡的滑动窗口长度。
const int kBalanceWindow = 6;

/// 允许的最大同侧连续次数。达到该长度后强制换边。
const int kBalanceMaxRun = 2;

/// 窗口内左右偏差达到该值时强制纠偏。
const int kBalanceDeviationThreshold = 2;

/// 目标左侧占比。
const double kBalanceTargetRatio = 0.5;

/// 二选一的选项数。
const int kBinaryOptionCount = AppConfig.binaryOptionCount;

/// 优先使用「用户历史混淆项」作为干扰项的概率。
const double kConfusionBias = 0.6;

/// 取历史混淆项时的候选数上限。
const int kTopConfusedLimit = 3;

// -----------------------------------------------------------------------------
// 混淆分析与弱项排行
// -----------------------------------------------------------------------------

/// 弱项音程对默认展示条数。
const int kWeakPairRankCount = 6;

/// 报告页混淆矩阵展示的 TOP 条目数。
const int kConfusionTopCount = AppConfig.confusionTopCount;

/// 弱项打分中「混淆次数」的权重。
const double kWeakPairConfusionWeight = 0.6;

/// 弱项打分中「掌握度缺口 (1 - mastery)」的权重。
const double kWeakPairMasteryWeight = 0.4;

/// 混淆次数归一化的参考值：达到该次数即视为「满分混淆」。
const double kWeakPairConfusionNormalizer = 10.0;

// -----------------------------------------------------------------------------
// 会话分段与章节推进（§5.7）
// -----------------------------------------------------------------------------

/// 每组默认题数。
const int kQuestionsPerSession = AppConfig.defaultQuestionsPerSession;

/// 章节通过线。
const double kChapterAdvanceAccuracy = 0.85;

/// 判定章节推进至少需要的会话数。
const int kChapterAdvanceMinSessions = 2;

/// 热身段占整组的比例（前 20%）。
const double kWarmUpSegmentRatio = 0.2;

/// 弱项攻坚段的结束位置（累计 70%）。
const double kWeakFocusSegmentRatio = 0.7;

/// 连击里程碑（触发徽章与粒子升级）。
const List<int> kComboMilestones = <int>[3, 5, 10, 15, 20];

/// 答错后插入的加练题数。
const int kExtraDrillQuestionCount = 3;

// -----------------------------------------------------------------------------
// 统计留存
// -----------------------------------------------------------------------------

/// `StatsSnapshot.recentOutcomes` 保留的最近作答条数。
const int kRecentOutcomeCapacity = 50;

/// 趋势图默认展示天数。
const int kTrendDays = AppConfig.trendDefaultDays;

/// 二选一模式 `PairStatistics.recentOutcomes` 保留的条数。
const int kPairRecentOutcomeCapacity = 20;
