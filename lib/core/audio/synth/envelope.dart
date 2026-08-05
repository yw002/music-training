import 'dart:math' as math;

import 'package:interval_ear/features/training/domain/models/enums.dart';

/// 合成器用的「起音/收音」淡变窗口（raised-cosine），用于消除爆音（click）。
///
/// 这是**合成器内部**用的防 click 包络，与下面的 [EnvelopeSampler]（播放可视化
/// 用）是**两套独立常量**——可视化包络的时间常数刻意与合成器不同（架构 §1.4）。
/// 二者不要为了「统一」而合并：可视化要的是「看起来对」，合成器要的是「物理上对」。
abstract final class RaisedCosineEnvelope {
  /// 计算第 [index] 个样本（共 [sampleCount] 个）的淡变系数，范围 [0, 1]。
  ///
  /// - 前 [attackMs] 毫秒：raised-cosine 从 0 升到 1（首样本必为 0，无 click）。
  /// - 中间：恒为 1。
  /// - 后 [releaseMs] 毫秒：raised-cosine 从 1 降到 0（尾样本趋近 0，无 click）。
  ///
  /// [sampleRate] 用于把毫秒换算成样本数；合成层统一用 44100。
  static double value({
    required int index,
    required int sampleCount,
    required double attackMs,
    required double releaseMs,
    required int sampleRate,
  }) {
    if (sampleCount <= 0) {
      return 0.0;
    }
    final int attackSamples = (attackMs * sampleRate / 1000).round();
    final int releaseSamples = (releaseMs * sampleRate / 1000).round();
    if (index < attackSamples && attackSamples > 0) {
      // raised-cosine 0→1：0.5 - 0.5·cos(πx)
      final double x = index / attackSamples;
      return 0.5 - 0.5 * math.cos(math.pi * x);
    }
    if (index >= sampleCount - releaseSamples && releaseSamples > 0) {
      // raised-cosine 1→0：对称，用「剩余样本比例」作自变量。
      final double x = (sampleCount - index) / releaseSamples;
      return 0.5 - 0.5 * math.cos(math.pi * x);
    }
    return 1.0;
  }
}

/// 播放可视化包络采样器（架构 §1.4 / §5.6）。
///
/// **纵深防御（防泄露）**：可视化幅度只由 `距该音符起音的毫秒数` 决定，绝不读取
/// 实时 PCM / FFT——FFT 会暴露基频，等于把答案画在屏幕上（PRD §3.1 事故级漏洞）。
/// 因此这里是一个**纯函数**，且输出与音高、音色都无关，保证 m2 与 M7 在任何
/// 时刻的渲染逐像素一致（§5.6 golden）。
///
/// **纯 Dart 实现**：刻意不用 `package:flutter` 的 `Curves`，保持合成层零 Flutter
/// 依赖，100% 可单测、可跨端一致。easing 用本地 [math] 实现。
abstract final class EnvelopeSampler {
  /// 可视化包络起音时长（毫秒）。
  ///
  /// 注意：与合成器真实衰减常数（键盘 ~1100ms / 拨弦依赖 damping）**故意不同**。
  /// 写进常量就是为了能被单测断言「没有被顺手统一」（T08 验收 6）。
  static const double kAttackMs = 600;

  /// 可视化包络收音时长（毫秒）。
  static const double kReleaseMs = 350;

  /// attack 段占整段的比例 = kAttackMs / (kAttackMs + kReleaseMs) ≈ 0.632。
  static double get attackFrac => kAttackMs / (kAttackMs + kReleaseMs);

  /// 整段可视化窗口（毫秒）= 起音 + 收音 = 950ms。
  static double get windowMs => kAttackMs + kReleaseMs;

  /// 由「距起音的毫秒数」得到可视化幅度 [0, 1]。
  ///
  /// [timbre] 仅用于接口兼容（调用方可能想按音色区分），但**返回值与音色无关**——
  /// 这是防泄露的硬性要求（同一 progress 下所有音程/音色渲染完全一致）。
  static double amplitudeAt(Timbre timbre, double msSinceNoteStart) {
    final double progress = (msSinceNoteStart / windowMs).clamp(0.0, 1.0);
    return shape(progress);
  }

  /// 包络形状函数（输入 progress ∈ [0,1]，输出 [0,1]）。
  ///
  /// attack 段用 easeOutCubic（快起慢落），release 段用 easeInCubic 的反相
  /// （慢起快落），保证 §5.6 的边界断言：shape(0)=0、shape(attackFrac)=1、shape(1)=0。
  static double shape(double progress) {
    final double p = progress.clamp(0.0, 1.0);
    final double frac = attackFrac;
    if (p < frac) {
      // easeOutCubic(x) = 1 - (1-x)^3
      final double x = p / frac;
      return 1 - math.pow(1 - x, 3).toDouble();
    }
    // 1 - easeInCubic(x)，x = (p - frac) / (1 - frac)
    final double x = (p - frac) / (1 - frac);
    return 1 - math.pow(x, 3).toDouble();
  }

  /// easeOutCubic（本地实现，避免引入 Flutter 依赖）。
  static double easeOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();

  /// easeInCubic（本地实现，避免引入 Flutter 依赖）。
  static double easeInCubic(double x) => math.pow(x, 3).toDouble();
}
