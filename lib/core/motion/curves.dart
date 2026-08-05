import 'package:flutter/animation.dart';

/// 曲线原语（PRD §3.0）。
///
/// 全项目**只允许**从这里取曲线。直接写 `Curves.easeInOut` 会让「统一调整缓动
/// 手感」变成全局搜索替换，而且无法保证同类动作用同一条曲线。
abstract final class AppCurve {
  const AppCurve._();

  /// 默认曲线：常规状态变化。
  static const Curve standard = Curves.easeOutCubic;

  /// 入场、涟漪扩散。
  static const Curve decelerate = Curves.easeOutQuart;

  /// 出场、消失。
  static const Curve accelerate = Curves.easeInCubic;

  /// MD3 emphasized，页面转场专用。
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// 面板 / 卡片入场。
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// 面板 / 卡片退场。
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// 按钮回弹、端点球。
  ///
  /// `Curves.easeOutBack` 默认 overshoot 1.70158，在答案按钮这类高频交互上
  /// 视觉过冲太明显，因此单独给一条收敛版 [overshootSubtle]（PRD §3.0 备注）。
  static const Curve overshoot = Curves.easeOutBack;

  /// 收敛版回弹（overshoot ≈ 1.2），答案按钮按压释放专用。
  ///
  /// `ElasticOutCurve` 不合适（振荡多次）；这里用等价的三次贝塞尔近似：
  /// 终点斜率为负、峰值约 1.06。
  static const Curve overshootSubtle = Cubic(0.34, 1.28, 0.64, 1.0);

  /// 全局限用：仅「一组训练完成」结算徽章 1 处。
  static const Curve spring = Curves.elasticOut;

  /// 进度、扫光、shimmer。
  static const Curve linear = Curves.linear;

  /// 呼吸循环。
  static const Curve breath = Curves.easeInOut;

  /// 全部曲线原语，按 token 名索引。供「曲线画廊」调试页与一致性测试使用。
  static const Map<String, Curve> all = <String, Curve>{
    'standard': standard,
    'decelerate': decelerate,
    'accelerate': accelerate,
    'emphasized': emphasized,
    'emphasizedDecelerate': emphasizedDecelerate,
    'emphasizedAccelerate': emphasizedAccelerate,
    'overshoot': overshoot,
    'overshootSubtle': overshootSubtle,
    'spring': spring,
    'linear': linear,
    'breath': breath,
  };
}
