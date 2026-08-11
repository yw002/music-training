import 'package:flutter/material.dart';

import 'package:interval_ear/app/theme/tokens_context_ext.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_view_model.dart';

/// 单个答案按钮（架构 §3.5 / T11）。
///
/// 交互态覆盖 `M-11` 按下 / `M-12` hover / `M-13` 焦点 / `M-14` 禁用，时长一律走
/// `context.tokens.motion.answer.*`，并通过 `context.mDur` 折算当前动效档位。
///
/// **防泄露护栏**：按钮只渲染 `AnswerOptionView` 的展示元数据（名字 / 半音数 /
/// 形状），**作答前**不携带任何「正确 / 选中」标记——所以 `ready` 与 `awaiting`
/// 下按钮逐像素一致（§5.6 golden）。`correct` / `selected` 的着色只在进入
/// [TrainingAnswered] 后由 [option] 的标记驱动（此时答案已可展示）。
class AnswerButton extends StatefulWidget {
  /// 创建答案按钮。
  const AnswerButton({
    required this.option,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  /// 展示数据（含是否正确/选中的标记，作答前均为 `false`）。
  final AnswerOptionView option;

  /// 点击回调（禁用时为 `null`）。
  final VoidCallback? onPressed;

  /// 是否可点击（等待作答时 `true`，其他阶段 `false`）。
  final bool enabled;

  @override
  State<AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<AnswerButton> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _pressed = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Color _surface(AppTokens tokens) {
    if (widget.option.isCorrect) {
      return tokens.color.success.container;
    }
    if (widget.option.isWrongSelected) {
      return tokens.color.warning.container;
    }
    if (widget.option.isSelected) {
      return tokens.color.answerSurfaceSelected;
    }
    if (_hovered) {
      return tokens.color.answerSurfaceHover;
    }
    return tokens.color.answerSurface;
  }

  Color _borderColor(AppTokens tokens) {
    if (widget.option.isCorrect) {
      return tokens.color.success.base;
    }
    if (widget.option.isWrongSelected) {
      return tokens.color.warning.base;
    }
    if (widget.option.isSelected) {
      return tokens.color.answerSurfaceSelected;
    }
    return tokens.color.answerBorder;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final answerTokens = tokens.motion.answer;
    final duration = context.mDur(answerTokens.press.enter.duration);
    final focusDuration = context.mDur(answerTokens.focus.enter.duration);
    final semanticLabel = AppStrings.a11y.answerOption(
      widget.option.name,
      widget.option.semitones,
    );
    final canPress = widget.enabled && widget.onPressed != null;

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: canPress,
      selected: widget.option.isSelected,
      child: Focus(
        focusNode: _focusNode,
        onFocusChange: (_) => setState(() {}),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTapDown: canPress ? (_) => setState(() => _pressed = true) : null,
            onTapUp: canPress ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTap: canPress ? widget.onPressed : null,
            child: AnimatedContainer(
              duration: _pressed ? duration : focusDuration,
              curve: Curves.easeOut,
              constraints: BoxConstraints(
                minHeight: tokens.space.minTouchTarget,
              ),
              decoration: BoxDecoration(
                color: _surface(tokens),
                borderRadius: BorderRadius.circular(tokens.radius.md),
                border: Border.all(
                  color: _borderColor(tokens),
                  width: _focusNode.hasFocus ? 2 : 1,
                ),
                boxShadow: _pressed
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                          color: tokens.scheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space.md,
                vertical: tokens.space.sm,
              ),
              child: _Content(option: widget.option, tokens: tokens),
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.option, required this.tokens});

  final AnswerOptionView option;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final primary = option.isCorrect
        ? tokens.color.success.onContainer
        : option.isWrongSelected
            ? tokens.color.warning.onContainer
            : tokens.scheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          option.name,
          style: tokens.type.titleMedium?.copyWith(
            color: primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.space.xxs),
        Text(
          _subtitle(),
          style: tokens.type.bodySmall
              ?.copyWith(color: primary.withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _subtitle() {
    final parts = <String>[
      if (option.shorthand.isNotEmpty) option.shorthand,
      AppStrings.unit.semitones(option.semitones),
    ];
    return parts.join(' · ');
  }
}
