import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 连击徽章（`M-22` combo.badge / comboNumber / comboRingRotation）。
///
/// 连击 > 0 时显示：徽章以 320ms overshoot 弹出（数字 200ms 切换），外圈以 1600ms
/// linear 持续旋转——但旋转仅在 `allowAmbient`（即 `MotionLevel.full`）时运行，
/// `reduced`/`off` 档下只显示静止终态（架构 §8.4）。连击数增加时重新触发弹出动画。
class ComboBadge extends StatefulWidget {
  /// 创建连击徽章。
  const ComboBadge({required this.combo, super.key});

  /// 当前连击数。
  final int combo;

  @override
  State<ComboBadge> createState() => _ComboBadgeState();
}

class _ComboBadgeState extends State<ComboBadge>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _popScale = CurvedAnimation(
    parent: _pop,
    curve: Curves.easeOutBack,
  );
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  int _prev = 0;

  bool _didInitDeps = false;

  @override
  void initState() {
    super.initState();
    // 旋转动画无需 context，留在 initState 启动；涉及 tokens 的取值移出（见下）。
    _ring.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 一次性守护：祖先 provider（TokensContextExt / MotionScope）此时已就绪，
    // 方可安全读取 context；保证弹出动画只启动一次。
    if (_didInitDeps) {
      return;
    }
    _didInitDeps = true;
    final duration = context.mDur(
      context.tokens.motion.progress.comboBadge.duration,
    );
    _pop.duration = duration;
    if (widget.combo > 0) {
      _pop.forward();
    }
  }

  @override
  void didUpdateWidget(ComboBadge old) {
    super.didUpdateWidget(old);
    if (widget.combo != old.combo) {
      final duration = context.mDur(
        context.tokens.motion.progress.comboBadge.duration,
      );
      _pop.duration = duration;
      if (widget.combo > _prev && widget.combo > 0) {
        _pop
          ..reset()
          ..forward();
      }
      _prev = widget.combo;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.combo <= 0) {
      return const SizedBox.shrink();
    }
    final tokens = context.tokens;
    final allowAmbient = context.allowAmbient;
    final label = AppStrings.training.comboCount(widget.combo);
    return ScaleTransition(
      scale: _popScale,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (allowAmbient)
            RotationTransition(
              turns: _ring,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.color.warning.base.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space.md,
              vertical: tokens.space.xs,
            ),
            decoration: BoxDecoration(
              color: tokens.color.warning.container,
              borderRadius: tokens.radius.pill,
            ),
            child: Text(
              label,
              style: tokens.type.titleSmall?.copyWith(
                color: tokens.color.warning.onContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
