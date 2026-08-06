import 'package:equatable/equatable.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';

/// 预置课程（原规范第十五章）。
///
/// 原规范明确：「课程预设只是自由训练配置的模板，不要另外实现一套重复的训练
/// 引擎」。因此 [CoursePreset] 只做一件事——把一组音程 [toConfig] 成
/// [TrainingConfig]，其余全部复用既有引擎。
class CoursePreset extends Equatable {
  /// 创建一个预设。
  const CoursePreset({
    required this.id,
    required this.nameZh,
    required this.intervals,
    required this.order,
  });

  /// 稳定 id（落盘到 `TrainingSession.presetId`，不可随意改）。
  final String id;

  /// 中文名（领域数据，随 [id] 绑定）。
  final String nameZh;

  /// 该预设包含的音程。
  final Set<IntervalId> intervals;

  /// 在列表中的展示顺序。
  final int order;

  /// 以 [base] 为模板，替换音程集合与答题模式。
  ///
  /// 只覆盖音程相关字段，方向/音色/题数等**保留用户当前偏好**——用户调好的
  /// 播放设置不该因为切换课程而被重置。
  TrainingConfig toConfig(TrainingConfig base) => base.copyWith(
        enabledIntervals: Set<IntervalId>.unmodifiable(intervals),
        answerMode: intervals.length == 2
            ? AnswerMode.binary
            : (base.answerMode == AnswerMode.binary
                ? AnswerMode.enabledOnly
                : base.answerMode),
      );

  @override
  List<Object?> get props =>
      <Object?>[id, nameZh, IntervalCatalog.sorted(intervals), order];

  @override
  String toString() => 'CoursePreset($id, ${intervals.length} intervals)';
}

/// 7 个预置课程的权威定义（原规范第十五章）。
abstract final class CoursePresets {
  const CoursePresets._();

  /// 基础音程：纯一度 / 纯五度 / 纯八度。
  static const CoursePreset basic = CoursePreset(
    id: 'basic',
    nameZh: '基础音程',
    order: 0,
    intervals: <IntervalId>{
      IntervalId.perfectUnison,
      IntervalId.perfectFifth,
      IntervalId.perfectOctave,
    },
  );

  /// 大小三度。
  static const CoursePreset thirds = CoursePreset(
    id: 'thirds',
    nameZh: '大小三度',
    order: 1,
    intervals: <IntervalId>{
      IntervalId.minorThird,
      IntervalId.majorThird,
    },
  );

  /// 大小二度。
  static const CoursePreset seconds = CoursePreset(
    id: 'seconds',
    nameZh: '大小二度',
    order: 2,
    intervals: <IntervalId>{
      IntervalId.minorSecond,
      IntervalId.majorSecond,
    },
  );

  /// 四度与五度。
  static const CoursePreset fourthsFifths = CoursePreset(
    id: 'fourths_fifths',
    nameZh: '四度与五度',
    order: 3,
    intervals: <IntervalId>{
      IntervalId.perfectFourth,
      IntervalId.perfectFifth,
    },
  );

  /// 大小六度。
  static const CoursePreset sixths = CoursePreset(
    id: 'sixths',
    nameZh: '大小六度',
    order: 4,
    intervals: <IntervalId>{
      IntervalId.minorSixth,
      IntervalId.majorSixth,
    },
  );

  /// 大小七度。
  static const CoursePreset sevenths = CoursePreset(
    id: 'sevenths',
    nameZh: '大小七度',
    order: 5,
    intervals: <IntervalId>{
      IntervalId.minorSeventh,
      IntervalId.majorSeventh,
    },
  );

  /// 全部音程：一个八度内的 13 个音程。
  static const CoursePreset allIntervals = CoursePreset(
    id: 'all',
    nameZh: '全部音程',
    order: 6,
    intervals: <IntervalId>{
      IntervalId.perfectUnison,
      IntervalId.minorSecond,
      IntervalId.majorSecond,
      IntervalId.minorThird,
      IntervalId.majorThird,
      IntervalId.perfectFourth,
      IntervalId.tritone,
      IntervalId.perfectFifth,
      IntervalId.minorSixth,
      IntervalId.majorSixth,
      IntervalId.minorSeventh,
      IntervalId.majorSeventh,
      IntervalId.perfectOctave,
    },
  );

  /// 全部 7 个预设，按展示顺序。
  static const List<CoursePreset> all = <CoursePreset>[
    basic,
    thirds,
    seconds,
    fourthsFifths,
    sixths,
    sevenths,
    allIntervals,
  ];

  /// 按 id 查找，未知返回 `null`。
  static CoursePreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
  }
}

/// 课程章节（架构 §9 未决项 5 的裁决：按半音数由易到难分 4 章，逐章累积）。
///
/// 用途：**冷启动**。全新用户零历史时所有音程 mastery 都是 0，如果直接把 13 个
/// 音程全放进 weak 桶，第一组训练就会同时出现三全音和大七度，挫败感极强
/// （架构 §4.3 边界表）。因此零历史时退化为第一章的 3 个音程。
class CourseChapter extends Equatable {
  /// 创建一章。
  const CourseChapter({
    required this.index,
    required this.nameZh,
    required this.intervals,
  });

  /// 章节序号，从 1 开始。
  final int index;

  /// 中文名。
  final String nameZh;

  /// 本章累计包含的音程（含前面各章）。
  final Set<IntervalId> intervals;

  @override
  List<Object?> get props =>
      <Object?>[index, nameZh, IntervalCatalog.sorted(intervals)];

  /// 以 [base] 为模板，生成该章的默认训练配置。
  ///
  /// 与 [CoursePreset.toConfig] 一致：仅替换音程集合与答题模式，保留用户
  /// 当前的播放设置。零历史时首页「今日练习」退化调用本方法（架构 §4.3）。
  TrainingConfig toConfig(TrainingConfig base) => base.copyWith(
        enabledIntervals: Set<IntervalId>.unmodifiable(intervals),
        answerMode: intervals.length == 2
            ? AnswerMode.binary
            : (base.answerMode == AnswerMode.binary
                ? AnswerMode.enabledOnly
                : base.answerMode),
      );

  @override
  String toString() => 'CourseChapter($index, ${intervals.length} intervals)';
}

/// 4 个章节的权威定义。
abstract final class CourseChapters {
  const CourseChapters._();

  /// 第一章：完全协和音程。
  static const CourseChapter one = CourseChapter(
    index: 1,
    nameZh: '完全协和',
    intervals: <IntervalId>{
      IntervalId.perfectUnison,
      IntervalId.perfectFifth,
      IntervalId.perfectOctave,
    },
  );

  /// 第二章：加入三度与六度。
  static const CourseChapter two = CourseChapter(
    index: 2,
    nameZh: '三度与六度',
    intervals: <IntervalId>{
      IntervalId.perfectUnison,
      IntervalId.perfectFifth,
      IntervalId.perfectOctave,
      IntervalId.minorThird,
      IntervalId.majorThird,
      IntervalId.minorSixth,
      IntervalId.majorSixth,
    },
  );

  /// 第三章：加入二度与七度。
  static const CourseChapter three = CourseChapter(
    index: 3,
    nameZh: '二度与七度',
    intervals: <IntervalId>{
      IntervalId.perfectUnison,
      IntervalId.perfectFifth,
      IntervalId.perfectOctave,
      IntervalId.minorThird,
      IntervalId.majorThird,
      IntervalId.minorSixth,
      IntervalId.majorSixth,
      IntervalId.minorSecond,
      IntervalId.majorSecond,
      IntervalId.minorSeventh,
      IntervalId.majorSeventh,
    },
  );

  /// 第四章：加入四度与三全音，全部 13 个。
  static const CourseChapter four = CourseChapter(
    index: 4,
    nameZh: '四度与三全音',
    intervals: <IntervalId>{
      IntervalId.perfectUnison,
      IntervalId.minorSecond,
      IntervalId.majorSecond,
      IntervalId.minorThird,
      IntervalId.majorThird,
      IntervalId.perfectFourth,
      IntervalId.tritone,
      IntervalId.perfectFifth,
      IntervalId.minorSixth,
      IntervalId.majorSixth,
      IntervalId.minorSeventh,
      IntervalId.majorSeventh,
      IntervalId.perfectOctave,
    },
  );

  /// 全部章节，按序号升序。
  static const List<CourseChapter> all = <CourseChapter>[one, two, three, four];

  /// 按序号取章节，越界钳制到 `[1, 4]`。
  static CourseChapter byIndex(int index) {
    if (index <= 1) {
      return one;
    }
    if (index >= all.length) {
      return four;
    }
    return all[index - 1];
  }
}
