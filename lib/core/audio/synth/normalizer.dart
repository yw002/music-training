import 'dart:math' as math;
import 'dart:typed_data';

/// 峰值归一与和声软限幅（架构 §5.5）。
///
/// 两个职责，但逻辑都很短，合在一个文件里：
/// 1. [normalize]：把单音 / 序列峰值压到 [kPeakTarget]，但**只在会削波时衰减**。
/// 2. [softLimit]：和声混音后逐样本软限幅（tanh 软膝），避免硬 clip 的刺耳失真。
abstract final class Normalizer {
  /// 峰值归一目标幅度（0.82）。留 18% 余量给和声叠加后的软限幅。
  static const double kPeakTarget = 0.82;

  /// 就地归一：仅当会削波时衰减，**绝不放大安静的音**。
  ///
  /// 为什么不能无条件归一到 0.82：衰减快的高音会被整体放大，导致不同音程的
  /// 主观响度不一致——用户可能靠响度而非音程作答，又是一条泄露路径（§5.5）。
  static void normalize(Float32List samples) {
    double peak = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final double a = samples[i].abs();
      if (a > peak) {
        peak = a;
      }
    }
    if (peak > 1e-9) {
      final double g = kPeakTarget / peak;
      // 铁律：g < 1.0 才衰减；g ≥ 1.0（安静/峰值本就很小）保持原样。
      if (g < 1.0) {
        for (int i = 0; i < samples.length; i++) {
          samples[i] *= g;
        }
      }
    }
  }

  /// 软限幅（tanh 软膝）。
  ///
  /// `|x| ≤ 0.95` 直出；超出部分用 `tanh` 平滑压到约 1，保留波形形状、避免硬削波。
  /// 用于和声混音后「两音相加略超 1」的兜底（虽 kVoiceGain=0.22 已保证 ≤0.44，
  /// 但多段叠加场景仍保留这道安全网）。
  static double softLimit(double x) {
    final double a = x.abs();
    if (a <= 0.95) {
      return x;
    }
    final double sign = x < 0 ? -1.0 : 1.0;
    final double y = (a - 0.95) / 0.05;
    return sign * (0.95 + 0.05 * _tanh(y));
  }

  /// 本地 tanh 实现（避免 `dart:math` 版本差异 & 溢出）：`tanh(y)=(eʸ-e⁻ʸ)/(eʸ+e⁻ʸ)`。
  static double _tanh(double x) {
    if (x > 20) {
      return 1.0;
    }
    if (x < -20) {
      return -1.0;
    }
    final double e = math.exp(x);
    final double eInv = math.exp(-x);
    return (e - eInv) / (e + eInv);
  }
}
