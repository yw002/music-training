/// 动效档位（PRD §3.10）。
///
/// 语义表（架构 §8.4，唯一权威定义）：
///
/// | 档位      | 循环动画 | 粒子 | 转场            | 一次性状态动画 | 终态 |
/// |-----------|---------|------|-----------------|---------------|------|
/// | `full`    | 正常     | 按设置 | 完整            | 完整时长       | 正常 |
/// | `reduced` | 全部停止 | 无   | 统一 150ms fade | 缩短至 ≤150ms  | 必须显示终态 |
/// | `off`     | 无       | 无   | 瞬时切换        | 瞬时到终态     | 必须显示终态 |
///
/// **最容易犯的错**：`reduced` 下把动画整个 `if` 掉，导致终态也不显示。
/// 每个动画组件都要「跳过过程，直达终态」，而不是「跳过整个组件」。
enum MotionLevel {
  /// 完整动效。
  full,

  /// 精简动效：保留必要的状态指示，去掉装饰性动画。
  reduced,

  /// 关闭动效：所有非状态指示类动画时长归零。
  off;

  /// 是否允许 ambient 循环动画（背景流动、呼吸光环、shimmer）。
  bool get allowsAmbient => this == MotionLevel.full;

  /// 是否允许粒子系统（频谱粒子、答对彩带）。
  bool get allowsParticles => this == MotionLevel.full;

  /// 是否允许位移 / 缩放类动画。`reduced` 起只保留 opacity crossfade。
  bool get allowsTransform => this == MotionLevel.full;

  /// `reduced` 档下的时长上限（毫秒）。`off` 档为 0。
  int get maxDurationMs => switch (this) {
        MotionLevel.full => 1 << 30,
        MotionLevel.reduced => 150,
        MotionLevel.off => 0,
      };
}

/// 用户在设置页选择的动效偏好（PRD §3.10 来源优先级第 1 项）。
///
/// 与 [MotionLevel] 分开建模的原因：`system` 不是一个「档位」，它是「让系统决定」，
/// 存进设置文件的必须是这个四值枚举，否则用户开了系统减弱动效再关掉时，
/// 我们无法恢复到「跟随系统」。
enum MotionPreference {
  /// 跟随系统的「减弱动态效果」开关（默认）。
  system('system'),

  /// 强制完整。
  full('full'),

  /// 强制精简。
  reduced('reduced'),

  /// 强制关闭。
  off('off');

  const MotionPreference(this.storageId);

  /// 落盘用的稳定字符串（架构 §8.6：禁止用 `enum.index`）。
  final String storageId;

  /// 默认偏好。
  static const MotionPreference defaultValue = MotionPreference.system;

  /// 从落盘字符串解析，未知值降级为 [defaultValue]。
  static MotionPreference fromStorageId(String? id) {
    for (final value in MotionPreference.values) {
      if (value.storageId == id) {
        return value;
      }
    }
    return defaultValue;
  }
}
