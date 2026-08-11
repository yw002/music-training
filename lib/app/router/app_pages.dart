import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:interval_ear/app/app_dependencies.dart';
import 'package:interval_ear/app/router/app_router.dart';
import 'package:interval_ear/app/router/route_names.dart';
import 'package:interval_ear/features/free_training/presentation/free_training_cubit.dart';
import 'package:interval_ear/features/free_training/presentation/free_training_page.dart';
import 'package:interval_ear/features/home/presentation/home_cubit.dart';
import 'package:interval_ear/features/home/presentation/home_page.dart';
import 'package:interval_ear/features/report/presentation/report_page.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_arguments.dart';
import 'package:interval_ear/features/session_summary/presentation/session_summary_page.dart';
import 'package:interval_ear/features/settings/presentation/about_page.dart';
import 'package:interval_ear/features/settings/presentation/settings_page.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_config.dart';
import 'package:interval_ear/features/training/domain/models/training_session.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_cubit.dart';
import 'package:interval_ear/features/training/presentation/pages/training_page.dart';

/// 集中登记本批次已落地的功能路由（架构 §1.3）。
///
/// `sessionSummary` 对应页面（T20 本组小结）与 `report` 对应页面（T21 报告与图表）
/// 均已实现并接入；`weakPairs` 不登记，由占位页兜底（架构 §8.4）。
/// [RouteNames.freeTraining] 由路由层用 `BlocProvider` 注入 [FreeTrainingCubit]，
/// 与训练页的工厂闭包同源。
AppRoutePages buildFeaturePages(AppDependencies deps) =>
    AppRoutePages.empty().withPages(<String, AppPageBuilder>{
      RouteNames.home: (BuildContext context, Object? arguments) =>
          BlocProvider<HomeCubit>(
            create: (_) => HomeCubit(
              trainingRepo: deps.trainingRepo,
              defaultTimbre: deps.settingsCubit.current.defaultTimbre,
            ),
            child: const HomePage(),
          ),
      RouteNames.training: (BuildContext context, Object? arguments) =>
          _training(deps, arguments, binary: false),
      RouteNames.binaryTraining: (BuildContext context, Object? arguments) =>
          _training(deps, arguments, binary: true),
      RouteNames.sessionSummary: (BuildContext context, Object? arguments) =>
          SessionSummaryPage(arguments: arguments as SessionSummaryArguments),
      RouteNames.freeTraining: (BuildContext context, Object? arguments) =>
          BlocProvider<FreeTrainingCubit>(
            create: (_) => FreeTrainingCubit(settingsRepo: deps.settingsRepo),
            child: const FreeTrainingPage(),
          ),
      RouteNames.report: (BuildContext context, Object? arguments) =>
          const ReportPage(),
      RouteNames.settings: (BuildContext context, Object? arguments) =>
          const SettingsPage(),
      RouteNames.about: (BuildContext context, Object? arguments) =>
          const AboutPage(),
    });

/// 训练页工厂闭包：用 [BlocProvider] 包住 [TrainingCubit]，确保 `TrainingPage`
/// 内 `context.read<TrainingCubit>()` / `context.read<AudioService>()` 不抛
/// `ProviderNotFoundException`（架构 §1.1）。
///
/// T23：把 Cubit 的「进行中会话」广播接到应用级 `ActiveSessionRegistry`，
/// 好让退到后台 / 关窗时能把没打完的一组标记为 `aborted` 落盘（验收 ⑥）。
/// 用回调而非直接注入登记处，是为了不让 `features/` 反向依赖 `app/`。
Widget _training(
  AppDependencies deps,
  Object? arguments, {
  required bool binary,
}) =>
    BlocProvider<TrainingCubit>(
      create: (_) => TrainingCubit(
        config: _configFromArgs(
          arguments,
          binary: binary,
          defaultTimbre: deps.settingsCubit.current.defaultTimbre,
        ),
        repository: deps.trainingRepo,
        audio: deps.audio,
        settings: deps.settingsCubit.current,
        onActiveSessionChanged: (TrainingSession? session) {
          if (session == null) {
            deps.activeSessions.clear();
          } else {
            deps.activeSessions.update(session);
          }
        },
      ),
      child: const TrainingPage(),
    );

/// 从路由参数解析训练配置。
///
/// - 直接传 [TrainingConfig] 时原样使用（首页「今日练习」、自由训练页等入口）；
/// - 否则退化为 [TrainingConfig.defaults]；
/// - [binary] 为真时强制改为「二选一」模式（取前两个可训练音程）。
TrainingConfig _configFromArgs(
  Object? arguments, {
  required bool binary,
  required Timbre defaultTimbre,
}) {
  final TrainingConfig base = arguments is TrainingConfig
      ? arguments
      : TrainingConfig.defaults.copyWith(
          timbreMode: defaultTimbre == Timbre.plucked
              ? TimbreMode.plucked
              : TimbreMode.keyboard,
        );
  if (!binary) {
    return base;
  }
  final Set<IntervalId> two = IntervalCatalog.trainableIds.take(2).toSet();
  return base.copyWith(enabledIntervals: two, answerMode: AnswerMode.binary);
}
