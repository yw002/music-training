import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:interval_ear/core/platform/platform_capabilities.dart';

/// 选择第 [index] 个答案（0 基）。数字键 `1`–`9` → 0–8，`0` → 9。
class SelectAnswerIntent extends Intent {
  /// 创建选答案意图。
  const SelectAnswerIntent(this.index);

  /// 答案下标（0 基）。
  final int index;
}

/// 重播当前题目（`Space`）。
class ReplayIntent extends Intent {
  /// 创建重播意图。
  const ReplayIntent();
}

/// 下一题 / 继续（`Enter`）。
class NextStepIntent extends Intent {
  /// 创建下一步意图。
  const NextStepIntent();
}

/// 选择「不确定」（`U`）。
class UncertainIntent extends Intent {
  /// 创建不确定意图。
  const UncertainIntent();
}

/// 开始今日练习（`Ctrl/⌘ + R`）。
class StartTrainingIntent extends Intent {
  /// 创建开始训练意图。
  const StartTrainingIntent();
}

/// 打开设置（`Ctrl/⌘ + ,`）。
class OpenSettingsIntent extends Intent {
  /// 创建打开设置意图。
  const OpenSettingsIntent();
}

/// 导出数据（`Ctrl/⌘ + E`）。
class ExportDataIntent extends Intent {
  /// 创建导出数据意图。
  const ExportDataIntent();
}

/// 返回 / 关闭面板（`Esc`）。
///
/// 独立于 Flutter 内置 `DismissIntent`，避免与对话框 / 弹层的默认关闭行为打架。
class AppDismissIntent extends Intent {
  /// 创建返回意图。
  const AppDismissIntent();
}

/// 桌面键盘快捷键的可复用装配（架构 §1.4 T22 / PRD §6.2）。
///
/// 设计要点（全部来自 PRD §6.2 硬性要求）：
/// 1. 用 `Shortcuts` + `Actions` + `Intent`，**`Intent` 与鼠标点击调用同一个
///    Cubit 方法**，不复制两套逻辑 —— 因此本 widget 只暴露回调，具体动作由页面
///    转发给自己的 Cubit；
/// 2. 文本框冲突：任一 `EditableText` 持有焦点时全部快捷键 `ignored`
///    （见 [isTextFieldFocused]）；
/// 3. 修饰键由平台决定：macOS `⌘`、其它 `Ctrl`（见 [primaryModifier]），
///    统一走 [PlatformCapabilities]，不裸写 `Platform.isX`；
/// 4. 只在窗口内生效，不注册全局热键、不接管媒体键。
///
/// 未传的回调不会注册对应 `Action`，按键自然向上冒泡，不会「吃掉」事件。
class AppShortcuts extends StatelessWidget {
  /// 创建快捷键装配。
  const AppShortcuts({
    required this.child,
    this.onSelectAnswer,
    this.onReplay,
    this.onNext,
    this.onUncertain,
    this.onStartTraining,
    this.onOpenSettings,
    this.onExportData,
    this.onDismiss,
    this.autofocus = true,
    this.enabled = true,
    super.key,
  });

  /// 被包裹的子树。
  final Widget child;

  /// 数字键选答案（0 基下标）。
  final ValueChanged<int>? onSelectAnswer;

  /// 空格重播。
  final VoidCallback? onReplay;

  /// 回车下一题 / 继续。
  final VoidCallback? onNext;

  /// `U` 选择「不确定」。
  final VoidCallback? onUncertain;

  /// `Ctrl/⌘ + R` 开始今日练习。
  final VoidCallback? onStartTraining;

  /// `Ctrl/⌘ + ,` 打开设置。
  final VoidCallback? onOpenSettings;

  /// `Ctrl/⌘ + E` 导出数据。
  final VoidCallback? onExportData;

  /// `Esc` 返回 / 关闭面板。
  final VoidCallback? onDismiss;

  /// 是否自动抢焦点（页面级用 `true`，嵌套复用时可传 `false`）。
  final bool autofocus;

  /// 是否启用（传 `false` 时完全透明，直接返回 [child]）。
  final bool enabled;

  /// 数字键顺序：`1`–`9` 对应下标 0–8，`0` 对应下标 9。
  static const List<LogicalKeyboardKey> _digitKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
    LogicalKeyboardKey.digit0,
  ];

  /// 小键盘数字，与 [_digitKeys] 同序。
  static const List<LogicalKeyboardKey> _numpadKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5,
    LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad8,
    LogicalKeyboardKey.numpad9,
    LogicalKeyboardKey.numpad0,
  ];

  /// 主修饰键：macOS `⌘`，其它平台 `Ctrl`（PRD §6.2 脚注）。
  static LogicalKeyboardKey get primaryModifier =>
      PlatformCapabilities.current.usesMetaShortcuts
          ? LogicalKeyboardKey.meta
          : LogicalKeyboardKey.control;

  /// 当前焦点是否落在文本输入框上。
  ///
  /// 是则所有业务快捷键让路（PRD §6.2「文本框冲突」）。
  ///
  /// `EditableText` 在组件树上是持有焦点的 `Focus` 的**子节点**，因此其焦点既可能
  /// 表现为「焦点上下文自身或其某个祖先就是 `EditableText` 的 context」，也可能
  /// 表现为「焦点上下文是包裹 `EditableText` 的 `Focus` 的 context、`EditableText`
  /// 位于其子树中」。两种情形都要覆盖：先向上查祖先，再向下遍历子树，任一处命中即
  /// 判为文本框聚焦。`primaryFocus` 为 `null`、或焦点节点未挂载（无 context，例如
  /// scope 根节点）时安全返回 `false`。
  static bool get isTextFieldFocused {
    final FocusNode? primary = FocusManager.instance.primaryFocus;
    final BuildContext? focusContext = primary?.context;
    if (focusContext is! Element) {
      return false;
    }
    // 1) 向上查祖先：焦点上下文自身或其某个祖先是 EditableText 的 context。
    if (focusContext.findAncestorWidgetOfExactType<EditableText>() != null) {
      return true;
    }
    // 2) 向下遍历子树：焦点上下文是包裹 EditableText 的 Focus，EditableText
    //    位于其子树中。
    bool found = false;
    void visit(Element element) {
      if (found) {
        return;
      }
      if (element.widget is EditableText) {
        found = true;
        return;
      }
      element.visitChildElements(visit);
    }

    visit(focusContext);
    return found;
  }

  /// 构造完整的按键 → 意图映射表（PRD §6.2 快捷键表）。
  static Map<ShortcutActivator, Intent> buildShortcutMap() {
    final bool useMeta = PlatformCapabilities.current.usesMetaShortcuts;
    SingleActivator withModifier(LogicalKeyboardKey key) =>
        SingleActivator(key, control: !useMeta, meta: useMeta);

    final Map<ShortcutActivator, Intent> map = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.space): const ReplayIntent(),
      const SingleActivator(LogicalKeyboardKey.enter): const NextStepIntent(),
      const SingleActivator(LogicalKeyboardKey.numpadEnter):
          const NextStepIntent(),
      const SingleActivator(LogicalKeyboardKey.keyU): const UncertainIntent(),
      const SingleActivator(LogicalKeyboardKey.escape):
          const AppDismissIntent(),
      withModifier(LogicalKeyboardKey.keyR): const StartTrainingIntent(),
      withModifier(LogicalKeyboardKey.comma): const OpenSettingsIntent(),
      withModifier(LogicalKeyboardKey.keyE): const ExportDataIntent(),
    };
    for (int i = 0; i < _digitKeys.length; i++) {
      map[SingleActivator(_digitKeys[i])] = SelectAnswerIntent(i);
      map[SingleActivator(_numpadKeys[i])] = SelectAnswerIntent(i);
    }
    return map;
  }

  Action<T> _guard<T extends Intent>(void Function(T intent) run) =>
      CallbackAction<T>(
        onInvoke: (T intent) {
          if (isTextFieldFocused) {
            return null;
          }
          run(intent);
          return null;
        },
      );

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final Map<Type, Action<Intent>> actions = <Type, Action<Intent>>{};
    if (onSelectAnswer != null) {
      actions[SelectAnswerIntent] = _guard<SelectAnswerIntent>(
        (SelectAnswerIntent intent) => onSelectAnswer!(intent.index),
      );
    }
    if (onReplay != null) {
      actions[ReplayIntent] = _guard<ReplayIntent>((_) => onReplay!());
    }
    if (onNext != null) {
      actions[NextStepIntent] = _guard<NextStepIntent>((_) => onNext!());
    }
    if (onUncertain != null) {
      actions[UncertainIntent] = _guard<UncertainIntent>((_) => onUncertain!());
    }
    if (onStartTraining != null) {
      actions[StartTrainingIntent] =
          _guard<StartTrainingIntent>((_) => onStartTraining!());
    }
    if (onOpenSettings != null) {
      actions[OpenSettingsIntent] =
          _guard<OpenSettingsIntent>((_) => onOpenSettings!());
    }
    if (onExportData != null) {
      actions[ExportDataIntent] =
          _guard<ExportDataIntent>((_) => onExportData!());
    }
    if (onDismiss != null) {
      actions[AppDismissIntent] = _guard<AppDismissIntent>((_) => onDismiss!());
    }

    return Shortcuts(
      shortcuts: buildShortcutMap(),
      child: Actions(
        actions: actions,
        child: Focus(
          autofocus: autofocus,
          canRequestFocus: true,
          skipTraversal: true,
          child: child,
        ),
      ),
    );
  }
}
