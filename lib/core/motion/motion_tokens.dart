import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:interval_ear/core/motion/curves.dart';
import 'package:interval_ear/core/motion/motion_level.dart';

/// 时长原语（PRD §3.0）。
///
/// 语义别名（`AppMotionTokens` 的 35 个 `M-xx`）优先于原语：页面代码应该写
/// `context.tokens.motion.answerPress`，而不是 `AppDuration.micro`。原语只在
/// 定义语义 token 时使用。
abstract final class AppDuration {
  const AppDuration._();

  /// 80ms：状态色切换、焦点环出现。
  static const Duration instant = Duration(milliseconds: 80);

  /// 120ms：按压、hover 进入。
  static const Duration micro = Duration(milliseconds: 120);

  /// 180ms：hover 退出、小元素淡入。
  static const Duration fast = Duration(milliseconds: 180);

  /// 260ms：常规组件出入场。
  static const Duration standard = Duration(milliseconds: 260);

  /// 400ms：页面转场、面板入场。
  static const Duration emphasized = Duration(milliseconds: 400);

  /// 600ms：大型强调（结算、报告 KPI）。
  static const Duration slow = Duration(milliseconds: 600);

  /// 1800ms：循环呼吸。
  static const Duration ambient = Duration(milliseconds: 1800);

  /// 4000ms：背景渐变流动。
  static const Duration ambientSlow = Duration(milliseconds: 4000);

  /// `reduced` 档的统一转场时长（PRD §3.10）。
  static const Duration reducedTransition = Duration(milliseconds: 150);

  /// `reduced` 档下通用组件动效的压缩时长（PRD §3.10）。
  static const Duration reducedComponent = Duration(milliseconds: 120);
}

/// 「时长 + 曲线」二元组，动效 token 的最小单位。
@immutable
class MotionSpec {
  /// 创建一个动效规格（毫秒 + 曲线）。
  ///
  /// 以毫秒（而非 `Duration`）作为存储字段，是因为 `Duration(milliseconds: x)`
  /// 在 const 构造函数的初始化列表里不是「潜在常量表达式」，会让整棵
  /// `AppMotionTokens.standard()` 常量树失效。
  const MotionSpec.ms(this.ms, this.curve);

  /// 时长由外部驱动（如音频序列长度）的规格，时长占位为 0。
  const MotionSpec.driven(this.curve) : ms = 0;

  /// 由 `Duration` 构造（运行时使用；不是 const）。
  factory MotionSpec.of(Duration duration, Curve curve) =>
      MotionSpec.ms(duration.inMilliseconds, curve);

  /// 动画时长毫秒数。
  final int ms;

  /// 缓动曲线。
  final Curve curve;

  /// 动画时长。
  Duration get duration => Duration(milliseconds: ms);

  /// 按 [MotionLevel] 折算后的有效时长。
  ///
  /// `full` 原样返回；`reduced` 压到 ≤150ms；`off` 归零。
  /// **注意**：归零只影响过程，组件仍然必须渲染终态（架构 §8.4）。
  Duration effectiveDurationFor(MotionLevel level) => switch (level) {
        MotionLevel.full => duration,
        MotionLevel.reduced => ms <= level.maxDurationMs
            ? duration
            : Duration(milliseconds: level.maxDurationMs),
        MotionLevel.off => Duration.zero,
      };

  /// 按 [MotionLevel] 折算后的完整规格。`reduced`/`off` 下曲线退化为 linear，
  /// 避免短时长上的缓动看起来像卡顿。
  MotionSpec effectiveFor(MotionLevel level) => level == MotionLevel.full
      ? this
      : MotionSpec.of(effectiveDurationFor(level), AppCurve.linear);

  /// 复制并覆盖部分字段。
  MotionSpec copyWith({Duration? duration, Curve? curve}) => MotionSpec.ms(
        duration?.inMilliseconds ?? ms,
        curve ?? this.curve,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionSpec && other.ms == ms && other.curve == curve);

  @override
  int get hashCode => Object.hash(ms, curve);

  @override
  String toString() => 'MotionSpec(${ms}ms, $curve)';
}

/// 交错入场规格（`M-05` / `M-17` / `M-24` / `M-27` / `M-28` 共用）。
@immutable
class MotionStaggerSpec {
  /// 创建交错入场规格。
  const MotionStaggerSpec({
    required this.item,
    required this.stepMs,
    required this.maxDelayMs,
    this.maxAnimatedItems = 0,
    this.explicitDelaysMs = const <int>[],
  });

  /// 单项自身的动画规格。
  final MotionSpec item;

  /// 相邻两项之间的延迟步进（毫秒）。
  final int stepMs;

  /// 延迟封顶（毫秒）。超过该值的项一律用封顶值，避免长列表末尾等太久。
  final int maxDelayMs;

  /// 只对前 N 项做交错，0 表示不限制（`M-28` 规定「仅前 8 项」）。
  final int maxAnimatedItems;

  /// 显式指定每一项的延迟（`M-17` 错题面板的 80/140/200/280 非均匀步进）。
  /// 非空时优先于 [stepMs]。
  final List<int> explicitDelaysMs;

  /// 第 [index] 项的入场延迟。
  Duration delayFor(int index) {
    if (index < 0) {
      throw RangeError.value(index, 'index', 'must be >= 0');
    }
    if (explicitDelaysMs.isNotEmpty) {
      final clamped =
          index < explicitDelaysMs.length ? index : explicitDelaysMs.length - 1;
      return Duration(milliseconds: explicitDelaysMs[clamped]);
    }
    if (maxAnimatedItems > 0 && index >= maxAnimatedItems) {
      // 超出交错范围的项直接用封顶延迟，和第 maxAnimatedItems 项一起出现。
      return Duration(
        milliseconds: _cap((maxAnimatedItems - 1) * stepMs),
      );
    }
    return Duration(milliseconds: _cap(index * stepMs));
  }

  int _cap(int value) => value > maxDelayMs ? maxDelayMs : value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionStaggerSpec &&
          other.item == item &&
          other.stepMs == stepMs &&
          other.maxDelayMs == maxDelayMs &&
          other.maxAnimatedItems == maxAnimatedItems &&
          listEquals(other.explicitDelaysMs, explicitDelaysMs));

  @override
  int get hashCode => Object.hash(
        item,
        stepMs,
        maxDelayMs,
        maxAnimatedItems,
        Object.hashAll(explicitDelaysMs),
      );

  @override
  String toString() =>
      'MotionStaggerSpec(item: $item, step: ${stepMs}ms, cap: ${maxDelayMs}ms)';
}

/// 半音尺对比条规格（`M-18`）：时长随半音数线性变化。
@immutable
class MotionRulerSpec {
  /// 创建半音尺规格。
  const MotionRulerSpec({
    required this.msPerSemitone,
    required this.minMs,
    required this.maxMs,
    required this.curve,
    required this.reducedFadeMs,
  });

  /// 每个半音的绘制耗时（毫秒）。
  final int msPerSemitone;

  /// 时长下界（毫秒）。
  final int minMs;

  /// 时长上界（毫秒）。
  final int maxMs;

  /// 缓动曲线。
  final Curve curve;

  /// `reduced`/`off` 档下直接绘制终态时的淡入时长（毫秒）。
  ///
  /// `M-18` 是**教学信息**不是装饰，降级时必须保留终态（PRD §3.10）。
  final int reducedFadeMs;

  /// 给定半音数时的实际时长。
  Duration durationForSemitones(int semitones) {
    final raw = semitones.abs() * msPerSemitone;
    final clamped = raw < minMs ? minMs : (raw > maxMs ? maxMs : raw);
    return Duration(milliseconds: clamped);
  }

  /// 按 [MotionLevel] 折算：降级档一律用 [reducedFadeMs] 的淡入。
  Duration effectiveFor(MotionLevel level, int semitones) => switch (level) {
        MotionLevel.full => durationForSemitones(semitones),
        MotionLevel.reduced => Duration(milliseconds: reducedFadeMs),
        MotionLevel.off => Duration.zero,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionRulerSpec &&
          other.msPerSemitone == msPerSemitone &&
          other.minMs == minMs &&
          other.maxMs == maxMs &&
          other.curve == curve &&
          other.reducedFadeMs == reducedFadeMs);

  @override
  int get hashCode =>
      Object.hash(msPerSemitone, minMs, maxMs, curve, reducedFadeMs);

  @override
  String toString() =>
      'MotionRulerSpec(${msPerSemitone}ms/semitone, $minMs..$maxMs)';
}

/// 粒子系统规格（`M-09` 频谱粒子、`M-15` 彩带）。
@immutable
class MotionParticleSpec {
  /// 创建粒子规格。
  const MotionParticleSpec({
    required this.life,
    required this.curve,
    required this.maxParticles,
    required this.degradedMaxParticles,
    required this.targetFps,
  });

  /// 单个粒子的寿命。
  final MotionSpec life;

  /// 运动曲线。
  final Curve curve;

  /// 粒子数上限。
  final int maxParticles;

  /// 看门狗一级降级后的粒子数上限（PRD §3.10：48 → 16）。
  final int degradedMaxParticles;

  /// 目标帧率。
  final int targetFps;

  /// 按是否降级返回当前允许的粒子数。
  int limitFor({required bool degraded}) =>
      degraded ? degradedMaxParticles : maxParticles;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionParticleSpec &&
          other.life == life &&
          other.curve == curve &&
          other.maxParticles == maxParticles &&
          other.degradedMaxParticles == degradedMaxParticles &&
          other.targetFps == targetFps);

  @override
  int get hashCode => Object.hash(
        life,
        curve,
        maxParticles,
        degradedMaxParticles,
        targetFps,
      );

  @override
  String toString() => 'MotionParticleSpec(life: $life, max: $maxParticles)';
}

/// 「进入 / 退出」两相规格。
@immutable
class MotionPairSpec {
  /// 创建两相规格。
  const MotionPairSpec({required this.enter, required this.exit});

  /// 进入相（按下、hover 进入、入场）。
  final MotionSpec enter;

  /// 退出相（抬起、hover 退出、退场）。
  final MotionSpec exit;

  /// 复制并覆盖部分字段。
  MotionPairSpec copyWith({MotionSpec? enter, MotionSpec? exit}) =>
      MotionPairSpec(enter: enter ?? this.enter, exit: exit ?? this.exit);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionPairSpec && other.enter == enter && other.exit == exit);

  @override
  int get hashCode => Object.hash(enter, exit);

  @override
  String toString() => 'MotionPairSpec(enter: $enter, exit: $exit)';
}

/// 「进入 → 停留 → 退出」三相规格（`M-23` 章节推进、`M-31` snackbar）。
@immutable
class MotionSequenceSpec {
  /// 创建三相规格。
  const MotionSequenceSpec({
    required this.enter,
    required this.hold,
    required this.exit,
  });

  /// 进入相。
  final MotionSpec enter;

  /// 停留时长（无缓动）。
  final Duration hold;

  /// 退出相。
  final MotionSpec exit;

  /// 三相总时长。
  Duration get total => enter.duration + hold + exit.duration;

  /// 复制并覆盖部分字段。
  MotionSequenceSpec copyWith({
    MotionSpec? enter,
    Duration? hold,
    MotionSpec? exit,
  }) =>
      MotionSequenceSpec(
        enter: enter ?? this.enter,
        hold: hold ?? this.hold,
        exit: exit ?? this.exit,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MotionSequenceSpec &&
          other.enter == enter &&
          other.hold == hold &&
          other.exit == exit);

  @override
  int get hashCode => Object.hash(enter, hold, exit);

  @override
  String toString() =>
      'MotionSequenceSpec(enter: $enter, hold: $hold, exit: $exit)';
}

// =============================================================================
// 语义 token 分组（PRD 附录 A · M-01 ~ M-35）
//
// 分组名与附录中 token 名的点号前缀一一对应，例如附录的 `answer.press` 对应
// `context.tokens.motion.answer.press`。少数因 Dart 关键字冲突或分组内只有单个
// token 而做的重命名，都在对应字段的注释里标注了附录原名。
// =============================================================================

/// 页面转场 token（`M-01` ~ `M-04`）。
@immutable
class TransitionMotionTokens {
  /// 创建转场 token 组。
  const TransitionMotionTokens({
    required this.homeToTraining,
    required this.trainingToReportConverge,
    required this.trainingToReport,
    required this.standardPush,
    required this.modalSheet,
    required this.reducedFade,
  });

  /// `M-01` `transition.homeToTraining`：卡片→整页容器变形。420 进 / 340 出。
  final MotionPairSpec homeToTraining;

  /// `M-02` `transition.trainingToReport` 的前置「成绩汇聚」相：240ms accelerate。
  final MotionSpec trainingToReportConverge;

  /// `M-02` `transition.trainingToReport` 主相：480ms emphasizedDecelerate。
  final MotionSpec trainingToReport;

  /// `M-03` `transition.standardPush`：Shared Axis X，300ms emphasized。
  final MotionSpec standardPush;

  /// `M-04` `transition.modalSheet`：底部面板进出，对齐 `M-34` 对话框参数。
  final MotionPairSpec modalSheet;

  /// `MotionLevel.reduced` / `off` 档下的统一 fade through（PRD §3.10：150ms linear）。
  final MotionSpec reducedFade;

  /// 复制并覆盖部分字段。
  TransitionMotionTokens copyWith({
    MotionPairSpec? homeToTraining,
    MotionSpec? trainingToReportConverge,
    MotionSpec? trainingToReport,
    MotionSpec? standardPush,
    MotionPairSpec? modalSheet,
    MotionSpec? reducedFade,
  }) =>
      TransitionMotionTokens(
        homeToTraining: homeToTraining ?? this.homeToTraining,
        trainingToReportConverge:
            trainingToReportConverge ?? this.trainingToReportConverge,
        trainingToReport: trainingToReport ?? this.trainingToReport,
        standardPush: standardPush ?? this.standardPush,
        modalSheet: modalSheet ?? this.modalSheet,
        reducedFade: reducedFade ?? this.reducedFade,
      );
}

/// 首页 token（`M-05` ~ `M-07`）。
@immutable
class HomeMotionTokens {
  /// 创建首页 token 组。
  const HomeMotionTokens({
    required this.cardStagger,
    required this.ambientFlow,
    required this.weakChipPulse,
  });

  /// `M-05` `home.cardStagger`：380ms，步进 60ms，封顶 300ms。
  final MotionStaggerSpec cardStagger;

  /// `M-06` `home.ambientFlow`：4000ms 循环背景流动。`reduced` 起停止取终帧。
  final MotionSpec ambientFlow;

  /// `M-07` `home.weakChipPulse`：2200ms 循环呼吸。
  final MotionSpec weakChipPulse;

  /// 复制并覆盖部分字段。
  HomeMotionTokens copyWith({
    MotionStaggerSpec? cardStagger,
    MotionSpec? ambientFlow,
    MotionSpec? weakChipPulse,
  }) =>
      HomeMotionTokens(
        cardStagger: cardStagger ?? this.cardStagger,
        ambientFlow: ambientFlow ?? this.ambientFlow,
        weakChipPulse: weakChipPulse ?? this.weakChipPulse,
      );
}

/// 播放可视化 token（`M-08` ~ `M-10`）。
@immutable
class VizMotionTokens {
  /// 创建可视化 token 组。
  const VizMotionTokens({
    required this.breathHaloAttack,
    required this.breathHaloLoop,
    required this.breathHaloRipple,
    required this.spectrumParticles,
    required this.minimal,
  });

  /// `M-08` `viz.breathHalo` 起手：160ms overshoot。
  final MotionSpec breathHaloAttack;

  /// `M-08` `viz.breathHalo` 循环：1800ms breath。
  final MotionSpec breathHaloLoop;

  /// `M-08` `viz.breathHalo` 涟漪：900ms decelerate。
  final MotionSpec breathHaloRipple;

  /// `M-09` `viz.spectrumParticles`：60fps，单粒子寿命 700ms linear。
  final MotionParticleSpec spectrumParticles;

  /// `M-10` `viz.minimal`：180ms overshoot（也是看门狗三级降级后的强制方案）。
  final MotionSpec minimal;

  /// 复制并覆盖部分字段。
  VizMotionTokens copyWith({
    MotionSpec? breathHaloAttack,
    MotionSpec? breathHaloLoop,
    MotionSpec? breathHaloRipple,
    MotionParticleSpec? spectrumParticles,
    MotionSpec? minimal,
  }) =>
      VizMotionTokens(
        breathHaloAttack: breathHaloAttack ?? this.breathHaloAttack,
        breathHaloLoop: breathHaloLoop ?? this.breathHaloLoop,
        breathHaloRipple: breathHaloRipple ?? this.breathHaloRipple,
        spectrumParticles: spectrumParticles ?? this.spectrumParticles,
        minimal: minimal ?? this.minimal,
      );
}

/// 答案按钮 token（`M-11` ~ `M-14`）。
@immutable
class AnswerMotionTokens {
  /// 创建答案按钮 token 组。
  const AnswerMotionTokens({
    required this.press,
    required this.hover,
    required this.focus,
    required this.disabled,
  });

  /// `M-11` `answer.press`：按下 90ms standard / 回弹 160ms overshoot(1.2)。
  final MotionPairSpec press;

  /// `M-12` `answer.hover`：进入 140ms / 退出 180ms，均 standard。
  final MotionPairSpec hover;

  /// `M-13` `answer.focus`：焦点环出现 120ms / 消失 80ms。
  ///
  /// 附录记为曲线 `instant`，那是**时长族**的名字；曲线层面用 standard。
  final MotionPairSpec focus;

  /// `M-14` `answer.disabled`：160ms linear 变灰。
  final MotionSpec disabled;

  /// 复制并覆盖部分字段。
  AnswerMotionTokens copyWith({
    MotionPairSpec? press,
    MotionPairSpec? hover,
    MotionPairSpec? focus,
    MotionSpec? disabled,
  }) =>
      AnswerMotionTokens(
        press: press ?? this.press,
        hover: hover ?? this.hover,
        focus: focus ?? this.focus,
        disabled: disabled ?? this.disabled,
      );
}

/// 作答反馈 token（`M-15` ~ `M-20`）。
@immutable
class FeedbackMotionTokens {
  /// 创建反馈 token 组。
  const FeedbackMotionTokens({
    required this.correct,
    required this.correctBlocking,
    required this.wrong,
    required this.wrongPanelEnter,
    required this.semitoneRuler,
    required this.abButton,
    required this.uncertain,
  });

  /// `M-15` `feedback.correct`：整段 620ms。
  final MotionSpec correct;

  /// `M-15` 中**阻塞用户操作**的那 180ms。超出这段必须允许输入打断（PRD B-1）。
  final MotionSpec correctBlocking;

  /// `M-16` `feedback.wrong`：220ms standard，随后展开错题面板。
  final MotionSpec wrong;

  /// `M-17` `wrongPanel.enter`：面板 420ms + 内部 80/140/200/280 非均匀交错。
  final MotionStaggerSpec wrongPanelEnter;

  /// `M-18` `compare.semitoneRuler`：半音数 × 40ms，钳制到 320–560ms。
  ///
  /// 这是**教学信息**，降级档必须保留终态（PRD §3.10）。
  final MotionRulerSpec semitoneRuler;

  /// `M-19` `compare.abButton`：进度环，时长由音频序列长度驱动，曲线固定 linear。
  final MotionSpec abButton;

  /// `M-20` `feedback.uncertain`：220ms standard 中性反馈。
  final MotionSpec uncertain;

  /// 复制并覆盖部分字段。
  FeedbackMotionTokens copyWith({
    MotionSpec? correct,
    MotionSpec? correctBlocking,
    MotionSpec? wrong,
    MotionStaggerSpec? wrongPanelEnter,
    MotionRulerSpec? semitoneRuler,
    MotionSpec? abButton,
    MotionSpec? uncertain,
  }) =>
      FeedbackMotionTokens(
        correct: correct ?? this.correct,
        correctBlocking: correctBlocking ?? this.correctBlocking,
        wrong: wrong ?? this.wrong,
        wrongPanelEnter: wrongPanelEnter ?? this.wrongPanelEnter,
        semitoneRuler: semitoneRuler ?? this.semitoneRuler,
        abButton: abButton ?? this.abButton,
        uncertain: uncertain ?? this.uncertain,
      );
}

/// 进度与激励 token（`M-21` ~ `M-23`）。
@immutable
class ProgressMotionTokens {
  /// 创建进度 token 组。
  const ProgressMotionTokens({
    required this.bar,
    required this.comboBadge,
    required this.comboNumber,
    required this.comboRingRotation,
    required this.chapterAdvance,
  });

  /// `M-21` `progress.bar`：320ms standard。
  final MotionSpec bar;

  /// `M-22` `combo.badge` 徽章弹出：320ms overshoot。
  final MotionSpec comboBadge;

  /// `M-22` 连击数字切换：200ms standard。
  final MotionSpec comboNumber;

  /// `M-22` 外圈旋转：1600ms linear 循环（`reduced` 起停止）。
  final MotionSpec comboRingRotation;

  /// `M-23` `chapter.advance`：进入 300 + 停留 1600 + 退出 240。
  final MotionSequenceSpec chapterAdvance;

  /// 复制并覆盖部分字段。
  ProgressMotionTokens copyWith({
    MotionSpec? bar,
    MotionSpec? comboBadge,
    MotionSpec? comboNumber,
    MotionSpec? comboRingRotation,
    MotionSequenceSpec? chapterAdvance,
  }) =>
      ProgressMotionTokens(
        bar: bar ?? this.bar,
        comboBadge: comboBadge ?? this.comboBadge,
        comboNumber: comboNumber ?? this.comboNumber,
        comboRingRotation: comboRingRotation ?? this.comboRingRotation,
        chapterAdvance: chapterAdvance ?? this.chapterAdvance,
      );
}

/// 报告页 token（`M-24` ~ `M-27`）。
@immutable
class ReportMotionTokens {
  /// 创建报告 token 组。
  const ReportMotionTokens({
    required this.entrance,
    required this.numberRoll,
    required this.barGrow,
    required this.lineGrow,
    required this.matrixReveal,
  });

  /// `M-24` `report.entrance`：360ms，步进 120ms。
  final MotionStaggerSpec entrance;

  /// `M-25` `report.numberRoll`：900ms decelerate（目标值为 0 时不滚动）。
  final MotionSpec numberRoll;

  /// `M-26` `report.chartGrow` 柱状部分：520ms，步进 40ms。
  final MotionStaggerSpec barGrow;

  /// `M-26` `report.chartGrow` 折线部分：800ms standard 描边。
  final MotionSpec lineGrow;

  /// `M-27` `report.matrixReveal`：单格 260ms overshoot，波步进 22ms，封顶 900ms。
  final MotionStaggerSpec matrixReveal;

  /// 复制并覆盖部分字段。
  ReportMotionTokens copyWith({
    MotionStaggerSpec? entrance,
    MotionSpec? numberRoll,
    MotionStaggerSpec? barGrow,
    MotionSpec? lineGrow,
    MotionStaggerSpec? matrixReveal,
  }) =>
      ReportMotionTokens(
        entrance: entrance ?? this.entrance,
        numberRoll: numberRoll ?? this.numberRoll,
        barGrow: barGrow ?? this.barGrow,
        lineGrow: lineGrow ?? this.lineGrow,
        matrixReveal: matrixReveal ?? this.matrixReveal,
      );
}

/// 通用组件 token（`M-28` ~ `M-35`）。
@immutable
class CommonMotionTokens {
  /// 创建通用 token 组。
  const CommonMotionTokens({
    required this.listItemStagger,
    required this.chipSelect,
    required this.switchToggle,
    required this.snackbar,
    required this.skeletonShimmer,
    required this.skeletonShowDelay,
    required this.tooltipDelay,
    required this.tooltipFade,
    required this.dialog,
    required this.destructiveConfirm,
  });

  /// `M-28` `list.itemStagger`：280ms，步进 40ms，**仅前 8 项**。
  final MotionStaggerSpec listItemStagger;

  /// `M-29` `chip.select`：选中 160ms standard / 回弹 180ms overshoot。
  final MotionPairSpec chipSelect;

  /// `M-30` `switch.toggle`：MD3 默认 200ms。
  ///
  /// 附录原名 `switch.toggle`；`switch` 是 Dart 关键字，无法作为分组名，
  /// 故合并为单个字段 `switchToggle`。
  final MotionSpec switchToggle;

  /// `M-31` `snackbar`：280 进 / 停留 3000 / 200 出。
  final MotionSequenceSpec snackbar;

  /// `M-32` `skeleton`：1200ms linear 循环 shimmer（`reduced` 起停止）。
  final MotionSpec skeletonShimmer;

  /// `M-32` 的显示阈值：120ms 内就绪则**完全不显示**骨架屏，避免闪一下。
  final Duration skeletonShowDelay;

  /// `M-33` `tooltip`：桌面 hover 后 500ms 才出现。
  final Duration tooltipDelay;

  /// `M-33` `tooltip` 淡入：140ms standard。
  final MotionSpec tooltipFade;

  /// `M-34` `dialog.enter`：260ms emphasizedDecelerate / 180ms accelerate。
  final MotionPairSpec dialog;

  /// `M-35` `dialog.destructiveConfirm`：长按 800ms linear / 回退 180ms accelerate。
  final MotionPairSpec destructiveConfirm;

  /// 复制并覆盖部分字段。
  CommonMotionTokens copyWith({
    MotionStaggerSpec? listItemStagger,
    MotionPairSpec? chipSelect,
    MotionSpec? switchToggle,
    MotionSequenceSpec? snackbar,
    MotionSpec? skeletonShimmer,
    Duration? skeletonShowDelay,
    Duration? tooltipDelay,
    MotionSpec? tooltipFade,
    MotionPairSpec? dialog,
    MotionPairSpec? destructiveConfirm,
  }) =>
      CommonMotionTokens(
        listItemStagger: listItemStagger ?? this.listItemStagger,
        chipSelect: chipSelect ?? this.chipSelect,
        switchToggle: switchToggle ?? this.switchToggle,
        snackbar: snackbar ?? this.snackbar,
        skeletonShimmer: skeletonShimmer ?? this.skeletonShimmer,
        skeletonShowDelay: skeletonShowDelay ?? this.skeletonShowDelay,
        tooltipDelay: tooltipDelay ?? this.tooltipDelay,
        tooltipFade: tooltipFade ?? this.tooltipFade,
        dialog: dialog ?? this.dialog,
        destructiveConfirm: destructiveConfirm ?? this.destructiveConfirm,
      );
}

/// 全部 35 个动效 token 的 `ThemeExtension`（PRD 附录 A）。
///
/// 通过 `context.tokens.motion.<分组>.<token>` 访问（架构 §8.3）。
/// 页面里出现任何 `Duration(milliseconds: N)` 字面量都视为违规。
@immutable
class AppMotionTokens extends ThemeExtension<AppMotionTokens> {
  /// 显式构造（仅供 [copyWith] 与测试使用；业务代码用 [standard]）。
  const AppMotionTokens({
    required this.transition,
    required this.home,
    required this.viz,
    required this.answer,
    required this.feedback,
    required this.progress,
    required this.report,
    required this.common,
  });

  /// 附录 A 的标准取值。深浅主题共用同一套（动效不随配色变化）。
  const AppMotionTokens.standard()
      : transition = const TransitionMotionTokens(
          // M-01
          homeToTraining: MotionPairSpec(
            enter: MotionSpec.ms(420, AppCurve.emphasized),
            exit: MotionSpec.ms(340, AppCurve.emphasizedAccelerate),
          ),
          // M-02（前置成绩汇聚 + 主转场）
          trainingToReportConverge: MotionSpec.ms(240, AppCurve.accelerate),
          trainingToReport: MotionSpec.ms(480, AppCurve.emphasizedDecelerate),
          // M-03
          standardPush: MotionSpec.ms(300, AppCurve.emphasized),
          // M-04
          modalSheet: MotionPairSpec(
            enter: MotionSpec.ms(260, AppCurve.emphasizedDecelerate),
            exit: MotionSpec.ms(180, AppCurve.accelerate),
          ),
          reducedFade: MotionSpec.ms(150, AppCurve.linear),
        ),
        home = const HomeMotionTokens(
          // M-05
          cardStagger: MotionStaggerSpec(
            item: MotionSpec.ms(380, AppCurve.emphasizedDecelerate),
            stepMs: 60,
            maxDelayMs: 300,
          ),
          // M-06
          ambientFlow: MotionSpec.ms(4000, AppCurve.breath),
          // M-07
          weakChipPulse: MotionSpec.ms(2200, AppCurve.breath),
        ),
        viz = const VizMotionTokens(
          // M-08
          breathHaloAttack: MotionSpec.ms(160, AppCurve.overshoot),
          breathHaloLoop: MotionSpec.ms(1800, AppCurve.breath),
          breathHaloRipple: MotionSpec.ms(900, AppCurve.decelerate),
          // M-09
          spectrumParticles: MotionParticleSpec(
            life: MotionSpec.ms(700, AppCurve.linear),
            curve: AppCurve.linear,
            maxParticles: 48,
            degradedMaxParticles: 16,
            targetFps: 60,
          ),
          // M-10
          minimal: MotionSpec.ms(180, AppCurve.overshoot),
        ),
        answer = const AnswerMotionTokens(
          // M-11
          press: MotionPairSpec(
            enter: MotionSpec.ms(90, AppCurve.standard),
            exit: MotionSpec.ms(160, AppCurve.overshootSubtle),
          ),
          // M-12
          hover: MotionPairSpec(
            enter: MotionSpec.ms(140, AppCurve.standard),
            exit: MotionSpec.ms(180, AppCurve.standard),
          ),
          // M-13
          focus: MotionPairSpec(
            enter: MotionSpec.ms(120, AppCurve.standard),
            exit: MotionSpec.ms(80, AppCurve.standard),
          ),
          // M-14
          disabled: MotionSpec.ms(160, AppCurve.linear),
        ),
        feedback = const FeedbackMotionTokens(
          // M-15
          correct: MotionSpec.ms(620, AppCurve.emphasizedDecelerate),
          correctBlocking: MotionSpec.ms(180, AppCurve.standard),
          // M-16
          wrong: MotionSpec.ms(220, AppCurve.standard),
          // M-17
          wrongPanelEnter: MotionStaggerSpec(
            item: MotionSpec.ms(420, AppCurve.emphasizedDecelerate),
            stepMs: 70,
            maxDelayMs: 280,
            explicitDelaysMs: <int>[80, 140, 200, 280],
          ),
          // M-18
          semitoneRuler: MotionRulerSpec(
            msPerSemitone: 40,
            minMs: 320,
            maxMs: 560,
            curve: AppCurve.emphasizedDecelerate,
            reducedFadeMs: 200,
          ),
          // M-19
          abButton: MotionSpec.driven(AppCurve.linear),
          // M-20
          uncertain: MotionSpec.ms(220, AppCurve.standard),
        ),
        progress = const ProgressMotionTokens(
          // M-21
          bar: MotionSpec.ms(320, AppCurve.standard),
          // M-22
          comboBadge: MotionSpec.ms(320, AppCurve.overshoot),
          comboNumber: MotionSpec.ms(200, AppCurve.standard),
          comboRingRotation: MotionSpec.ms(1600, AppCurve.linear),
          // M-23
          chapterAdvance: MotionSequenceSpec(
            enter: MotionSpec.ms(300, AppCurve.emphasizedDecelerate),
            hold: Duration(milliseconds: 1600),
            exit: MotionSpec.ms(240, AppCurve.emphasizedAccelerate),
          ),
        ),
        report = const ReportMotionTokens(
          // M-24
          entrance: MotionStaggerSpec(
            item: MotionSpec.ms(360, AppCurve.emphasizedDecelerate),
            stepMs: 120,
            maxDelayMs: 480,
          ),
          // M-25
          numberRoll: MotionSpec.ms(900, AppCurve.decelerate),
          // M-26
          barGrow: MotionStaggerSpec(
            item: MotionSpec.ms(520, AppCurve.emphasizedDecelerate),
            stepMs: 40,
            maxDelayMs: 480,
          ),
          lineGrow: MotionSpec.ms(800, AppCurve.standard),
          // M-27
          matrixReveal: MotionStaggerSpec(
            item: MotionSpec.ms(260, AppCurve.overshoot),
            stepMs: 22,
            maxDelayMs: 900,
          ),
        ),
        common = const CommonMotionTokens(
          // M-28
          listItemStagger: MotionStaggerSpec(
            item: MotionSpec.ms(280, AppCurve.emphasizedDecelerate),
            stepMs: 40,
            maxDelayMs: 280,
            maxAnimatedItems: 8,
          ),
          // M-29
          chipSelect: MotionPairSpec(
            enter: MotionSpec.ms(160, AppCurve.standard),
            exit: MotionSpec.ms(180, AppCurve.overshoot),
          ),
          // M-30
          switchToggle: MotionSpec.ms(200, AppCurve.standard),
          // M-31
          snackbar: MotionSequenceSpec(
            enter: MotionSpec.ms(280, AppCurve.emphasizedDecelerate),
            hold: Duration(milliseconds: 3000),
            exit: MotionSpec.ms(200, AppCurve.accelerate),
          ),
          // M-32
          skeletonShimmer: MotionSpec.ms(1200, AppCurve.linear),
          skeletonShowDelay: Duration(milliseconds: 120),
          // M-33
          tooltipDelay: Duration(milliseconds: 500),
          tooltipFade: MotionSpec.ms(140, AppCurve.standard),
          // M-34
          dialog: MotionPairSpec(
            enter: MotionSpec.ms(260, AppCurve.emphasizedDecelerate),
            exit: MotionSpec.ms(180, AppCurve.accelerate),
          ),
          // M-35
          destructiveConfirm: MotionPairSpec(
            enter: MotionSpec.ms(800, AppCurve.linear),
            exit: MotionSpec.ms(180, AppCurve.accelerate),
          ),
        );

  /// 页面转场（`M-01` ~ `M-04`）。
  final TransitionMotionTokens transition;

  /// 首页（`M-05` ~ `M-07`）。
  final HomeMotionTokens home;

  /// 播放可视化（`M-08` ~ `M-10`）。
  final VizMotionTokens viz;

  /// 答案按钮（`M-11` ~ `M-14`）。
  final AnswerMotionTokens answer;

  /// 作答反馈（`M-15` ~ `M-20`）。
  final FeedbackMotionTokens feedback;

  /// 进度与激励（`M-21` ~ `M-23`）。
  final ProgressMotionTokens progress;

  /// 报告页（`M-24` ~ `M-27`）。
  final ReportMotionTokens report;

  /// 通用组件（`M-28` ~ `M-35`）。
  final CommonMotionTokens common;

  // ---------------------------------------------------------------------------
  // 高频别名（架构 §8.3 示例中的短写法）
  // ---------------------------------------------------------------------------

  /// `M-11` 按下相。等价于 `answer.press.enter`。
  MotionSpec get answerPress => answer.press.enter;

  /// `M-11` 回弹相。等价于 `answer.press.exit`。
  MotionSpec get answerRelease => answer.press.exit;

  /// `M-21` 进度条。等价于 `progress.bar`。
  MotionSpec get progressBar => progress.bar;

  /// `reduced` / `off` 档统一转场。等价于 `transition.reducedFade`。
  MotionSpec get reducedFade => transition.reducedFade;

  // ---------------------------------------------------------------------------
  // 附录 A 编号索引
  // ---------------------------------------------------------------------------

  /// 附录 A 的全部 35 个编号，顺序固定。
  static const List<String> tokenCodes = <String>[
    'M-01', 'M-02', 'M-03', 'M-04', 'M-05', 'M-06', 'M-07', 'M-08', 'M-09',
    'M-10', 'M-11', 'M-12', 'M-13', 'M-14', 'M-15', 'M-16', 'M-17', 'M-18',
    'M-19', 'M-20', 'M-21', 'M-22', 'M-23', 'M-24', 'M-25', 'M-26', 'M-27',
    'M-28', 'M-29', 'M-30', 'M-31', 'M-32', 'M-33', 'M-34', 'M-35',
  ];

  /// 按附录编号取回 token 对象。未知编号抛 [ArgumentError]。
  ///
  /// 存在的意义：让「35 个 token 一个不少」这件事**可被测试机械验证**，
  /// 而不是靠人眼数注释。
  Object tokenByCode(String code) => switch (code) {
        'M-01' => transition.homeToTraining,
        'M-02' => transition.trainingToReport,
        'M-03' => transition.standardPush,
        'M-04' => transition.modalSheet,
        'M-05' => home.cardStagger,
        'M-06' => home.ambientFlow,
        'M-07' => home.weakChipPulse,
        'M-08' => viz.breathHaloLoop,
        'M-09' => viz.spectrumParticles,
        'M-10' => viz.minimal,
        'M-11' => answer.press,
        'M-12' => answer.hover,
        'M-13' => answer.focus,
        'M-14' => answer.disabled,
        'M-15' => feedback.correct,
        'M-16' => feedback.wrong,
        'M-17' => feedback.wrongPanelEnter,
        'M-18' => feedback.semitoneRuler,
        'M-19' => feedback.abButton,
        'M-20' => feedback.uncertain,
        'M-21' => progress.bar,
        'M-22' => progress.comboBadge,
        'M-23' => progress.chapterAdvance,
        'M-24' => report.entrance,
        'M-25' => report.numberRoll,
        'M-26' => report.barGrow,
        'M-27' => report.matrixReveal,
        'M-28' => common.listItemStagger,
        'M-29' => common.chipSelect,
        'M-30' => common.switchToggle,
        'M-31' => common.snackbar,
        'M-32' => common.skeletonShimmer,
        'M-33' => common.tooltipFade,
        'M-34' => common.dialog,
        'M-35' => common.destructiveConfirm,
        _ => throw ArgumentError.value(code, 'code', 'unknown motion token'),
      };

  @override
  AppMotionTokens copyWith({
    TransitionMotionTokens? transition,
    HomeMotionTokens? home,
    VizMotionTokens? viz,
    AnswerMotionTokens? answer,
    FeedbackMotionTokens? feedback,
    ProgressMotionTokens? progress,
    ReportMotionTokens? report,
    CommonMotionTokens? common,
  }) =>
      AppMotionTokens(
        transition: transition ?? this.transition,
        home: home ?? this.home,
        viz: viz ?? this.viz,
        answer: answer ?? this.answer,
        feedback: feedback ?? this.feedback,
        progress: progress ?? this.progress,
        report: report ?? this.report,
        common: common ?? this.common,
      );

  /// 主题切换时的插值。
  ///
  /// 这里**故意**在 t=0.5 处硬切而不做连续插值：时长与曲线插值没有物理意义，
  /// 若在主题过渡的 300ms 内让 `answer.press` 从 90ms 平滑变成 90ms（深浅相同）
  /// 只会白白产生一堆临时对象；而当未来真的出现深浅不同的动效参数时，硬切也比
  /// 「转场途中动画时长在漂移」更可预期。
  @override
  AppMotionTokens lerp(ThemeExtension<AppMotionTokens>? other, double t) {
    if (other is! AppMotionTokens) {
      return this;
    }
    return t < 0.5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppMotionTokens &&
          other.transition == transition &&
          other.home == home &&
          other.viz == viz &&
          other.answer == answer &&
          other.feedback == feedback &&
          other.progress == progress &&
          other.report == report &&
          other.common == common;

  @override
  int get hashCode => Object.hash(
        transition,
        home,
        viz,
        answer,
        feedback,
        progress,
        report,
        common,
      );
}
