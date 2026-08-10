import 'package:flutter/widgets.dart';

import 'package:interval_ear/core/widgets/responsive/breakpoint_scope.dart';

/// 断点感知的构建器（架构 §1.4 T22，纯 Flutter 内置实现，不引第三方响应式库）。
///
/// 用法（页面**最外层**包一层即可，内部组件不必重排）：
/// ```dart
/// ResponsiveBuilder(
///   builder: (BuildContext context, Breakpoint bp) =>
///       bp.isExpanded ? _wideLayout() : _narrowLayout(),
/// )
/// ```
///
/// 实现说明：
/// - 用 `MediaQuery.sizeOf(context).width` 判定档位（只订阅 size，窗口 resize 会
///   重建，但不会因为其它 MediaQuery 字段变化而多余重建）；
/// - 同时把档位通过 [BreakpointScope] 广播下去，子树任意深度都能
///   `context.breakpoint` 读到，避免层层透传参数；
/// - `builder` 拿到的 `context` 位于 [BreakpointScope] **之下**（内部套了
///   `Builder`），因此 `context.breakpoint` 一定读得到本层广播的值。
class ResponsiveBuilder extends StatelessWidget {
  /// 创建响应式构建器。
  const ResponsiveBuilder({required this.builder, super.key});

  /// 布局构建回调，第二个参数为当前档位。
  final Widget Function(BuildContext context, Breakpoint breakpoint) builder;

  @override
  Widget build(BuildContext context) {
    final Breakpoint breakpoint =
        Breakpoint.fromWidth(MediaQuery.sizeOf(context).width);
    return BreakpointScope(
      breakpoint: breakpoint,
      child: Builder(
        builder: (BuildContext inner) => builder(inner, breakpoint),
      ),
    );
  }
}
