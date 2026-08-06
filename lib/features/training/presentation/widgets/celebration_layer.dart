import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/features/training/domain/algorithm_constants.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/presentation/widgets/particle_system.dart';

/// 答对庆祝层（架构 §3.10 / T14）。
///
/// 叠加在训练内容之上的庆祝图层：连击达到里程碑时发射粒子 + 弹出一个短暂放大淡出的
/// 连击文字。粒子数受 [CelebrationLevel] + [MotionGovernor] 双重约束（见
/// [ParticleSystem]）。`off` 档完全不渲染（[ParticleSystem] 内部也会判空）。
///
/// 粒子数阈值（subtle 默认）：
/// - combo < 3 → 0（不庆祝）
/// - 3–4 → 8
/// - 5–9 → 14
/// - ≥10 → 20（金色）
/// rich 档：阈值整体下调 2 档，且粒子数 ×1.6。
class CelebrationLayer extends StatefulWidget {
  /// 创建庆祝层。
  const CelebrationLayer({
    required this.combo,
    required this.level,
    required this.color,
    super.key,
  });

  /// 当前连击数。
  final int combo;

  /// 庆祝强度。
  final CelebrationLevel level;

  /// 粒子颜色。
  final Color color;

  @override
  State<CelebrationLayer> createState() => _CelebrationLayerState();
}

/// 按庆祝强度与连击数计算粒子数（已含 rich 档调整）。
int particleCountFor(int combo, CelebrationLevel level) {
  if (level == CelebrationLevel.off) {
    return 0;
  }
  int base;
  if (level == CelebrationLevel.rich) {
    // 阈值下调 2 档。
    if (combo < 1) {
      base = 0;
    } else if (combo < 3) {
      base = 8;
    } else if (combo < 8) {
      base = 14;
    } else {
      base = 20;
    }
    base = (base * 1.6).round();
  } else {
    if (combo < 3) {
      base = 0;
    } else if (combo < 5) {
      base = 8;
    } else if (combo < 10) {
      base = 14;
    } else {
      base = 20;
    }
  }
  return base;
}

class _CelebrationLayerState extends State<CelebrationLayer> {
  int _burstKey = 0;
  int _prevCombo = 0;

  @override
  void initState() {
    super.initState();
    _prevCombo = widget.combo;
    _maybeBurst();
  }

  @override
  void didUpdateWidget(CelebrationLayer old) {
    super.didUpdateWidget(old);
    if (widget.combo != _prevCombo) {
      _prevCombo = widget.combo;
      _maybeBurst();
    }
  }

  void _maybeBurst() {
    if (particleCountFor(widget.combo, widget.level) > 0) {
      setState(() => _burstKey += 1);
    }
  }

  bool get _isMilestone => kComboMilestones.contains(widget.combo);

  @override
  Widget build(BuildContext context) {
    final count = particleCountFor(widget.combo, widget.level);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (count > 0)
          Positioned.fill(
            child: Center(
              child: ParticleSystem(
                burstKey: _burstKey,
                count: count,
                color: widget.color,
              ),
            ),
          ),
        if (_isMilestone && count > 0)
          Positioned.fill(
            child: Center(child: _ComboPop(combo: widget.combo)),
          ),
      ],
    );
  }
}

/// 连击里程碑时的短暂放大淡出文字。
class _ComboPop extends StatefulWidget {
  const _ComboPop({required this.combo});

  /// 连击数。
  final int combo;

  @override
  State<_ComboPop> createState() => _ComboPopState();
}

class _ComboPopState extends State<_ComboPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.4, end: 1.2)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  late final Animation<double> _opacity = Tween<double>(begin: 1, end: 0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: Text(
          AppStrings.training.comboCount(widget.combo),
          style: tokens.type.headlineSmall?.copyWith(
            color: tokens.color.warning.base,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
