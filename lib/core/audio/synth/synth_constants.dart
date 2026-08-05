import 'package:interval_ear/core/constants/app_config.dart';

/// 合成层共享常量（架构 §5.5）。
///
/// 集中放置所有合成算法常量，禁止在逻辑里散落魔法数字——这样调参只动这一处，
/// 也方便单测逐条断言。每个常量的出处都在对应 Voice / Envelope 文件里注明。
abstract final class SynthConstants {
  /// 采样率，与 [AppConfig.sampleRate] 一致（44100Hz）。
  ///
  /// 合成层不直接读 [AppConfig] 也能跑，但二者必须相等——这是「四端听感一致」
  /// 的前提（架构 §1.2.1：波形在 Dart 层就已经字节相同）。
  static const int sampleRate = AppConfig.sampleRate;

  /// 单音增益。键盘 / 拨弦两种音色都乘这个系数。
  ///
  /// 为什么是 0.22：两音叠加（和声模式）后峰值为 0.44 ≤ 0.82，永远不会削波，
  /// 留出了软限幅的安全余量（架构 §5.5）。
  static const double kVoiceGain = 0.22;
}
