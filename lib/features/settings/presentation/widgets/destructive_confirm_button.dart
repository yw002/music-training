import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';

/// 长按确认按钮（M-35 销毁确认）：需长按满 800ms（linear）才触发 [onConfirmed]。
///
/// 普通态显示 [label]；长按过程中显示 [confirmLabel] 并以线性进度条反馈进度；
/// 未满即松手则回退、不触发。动效时长取自 `tokens.motion.common.destructiveConfirm`。
class DestructiveConfirmButton extends StatefulWidget {
  /// 创建长按确认按钮。
  const DestructiveConfirmButton({
    required this.label,
    required this.confirmLabel,
    required this.onConfirmed,
    super.key,
  });

  /// 正常态文案（如「清空全部数据」）。
  final String label;

  /// 长按过程中的提示文案（如「长按确认清空」）。
  final String confirmLabel;

  /// 长按满时长后触发的回调。
  final VoidCallback onConfirmed;

  @override
  State<DestructiveConfirmButton> createState() =>
      _DestructiveConfirmButtonState();
}

class _DestructiveConfirmButtonState extends State<DestructiveConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_onProgress);
  }

  void _onProgress() {
    if (_controller.isCompleted && !_fired) {
      _fired = true;
      widget.onConfirmed();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration duration = context.mDur(
      context.tokens.motion.common.destructiveConfirm.enter.duration,
    );
    if (_controller.duration != duration) {
      _controller.duration = duration;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onProgress)
      ..dispose();
    super.dispose();
  }

  void _begin() {
    _fired = false;
    _controller.forward();
  }

  void _cancel() {
    if (!_controller.isCompleted) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = context.tokens;
    final bool pressing = _controller.value > 0 && !_controller.isCompleted;
    return GestureDetector(
      onLongPressStart: (_) => _begin(),
      onLongPressEnd: (_) => _cancel(),
      onLongPressCancel: _cancel,
      child: ClipRRect(
        borderRadius: tokens.radius.button,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: double.infinity,
              height: tokens.space.minTouchTarget,
              alignment: Alignment.center,
              color: tokens.scheme.errorContainer,
              child: Text(
                pressing ? widget.confirmLabel : widget.label,
                style: tokens.type.labelLarge?.copyWith(
                  color: tokens.scheme.onErrorContainer,
                ),
              ),
            ),
            Positioned.fill(
              child: LinearProgressIndicator(
                value: _controller.value,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  tokens.scheme.error.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
