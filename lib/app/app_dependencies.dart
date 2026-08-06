import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:interval_ear/app/router/app_router.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/core/audio/soloud_audio_service.dart';
import 'package:interval_ear/core/constants/app_config.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/features/settings/presentation/settings_cubit.dart';
import 'package:interval_ear/features/training/data/settings_repository_impl.dart';
import 'package:interval_ear/features/training/data/training_repository_impl.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';
import 'package:path_provider/path_provider.dart';

/// 应用级依赖容器（架构 §1.4 手写依赖装配，不引 DI 框架）。
///
/// 只装「进程内单例、跨页面共享、生命周期与 App 等长」的对象。页面级
/// Bloc / Cubit 由各自 feature 在 `BlocProvider` 里创建，不进这里。
///
/// 装配顺序固定为：基础设施（日志 / 存储）→ 领域服务 → 表现层（路由）。
/// 后续任务往里加字段时，请保持 [dispose] 的释放顺序与创建顺序相反。
@immutable
class AppDependencies {
  /// 直接构造（测试可传入替身）。
  const AppDependencies({
    required this.navigatorKey,
    required this.motionGovernor,
    required this.router,
    required this.audio,
    required this.trainingRepo,
    required this.settingsRepo,
    required this.settingsCubit,
  });

  /// 全局 Navigator key。`AppRouter` 借它在无 `BuildContext` 时读动效档位。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 帧性能看门狗（架构 §1.8）。
  final MotionGovernor motionGovernor;

  /// 集中式路由器。
  final AppRouter router;

  /// 音频播放服务（生产用 [SoLoudAudioService]，初始化失败降级 [FakeAudioService]）。
  final AudioService audio;

  /// 训练数据仓储（JSONL 流水 + stats.json 缓存）。
  final TrainingRepository trainingRepo;

  /// 设置仓储（原子写，重启保留）。
  final SettingsRepository settingsRepo;

  /// 应用级设置状态源（T17 新增，持有 [AppSettings]）。
  final SettingsCubit settingsCubit;

  /// 生产环境装配。
  ///
  /// [pages] 为功能页面登记表；随着 feature 任务落地逐步填充，未登记的路由
  /// 会回落到 `RoutePlaceholderPage`，不会崩溃。
  static Future<AppDependencies> bootstrap({
    AppRoutePages pages = const AppRoutePages.empty(),
    bool startGovernor = true,
  }) async {
    final GlobalKey<NavigatorState> navigatorKey =
        GlobalKey<NavigatorState>(debugLabel: 'appNavigator');
    final MotionGovernor governor = MotionGovernor();
    if (startGovernor) {
      governor.start();
    }
    final AppRouter router = AppRouter(
      pages: pages,
      motionLevelResolver: AppRouter.resolverFor(navigatorKey),
    );

    // 数据目录：文档目录下的应用子目录，确保存在后交给仓储实现。
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory dataDir = Directory(
      <String>[documents.path, AppConfig.dataDirName].join('/'),
    );
    await dataDir.create(recursive: true);

    // 音频：先尝试 SoLoud，初始化失败（引擎不可用）则降级到 Fake（T09 验收 4）。
    final SoLoudAudioService soLoud = SoLoudAudioService();
    await soLoud.initialize();
    final AudioService audio;
    if (soLoud.isAvailable) {
      audio = soLoud;
    } else {
      await soLoud.dispose();
      audio = FakeAudioService();
    }

    final SettingsRepository settingsRepo = SettingsRepositoryImpl(
      dataDir: dataDir,
    );
    final TrainingRepository trainingRepo = TrainingRepositoryImpl(
      dataDir: dataDir,
    );
    final SettingsCubit settingsCubit = SettingsCubit(repository: settingsRepo);
    // 构造时即加载已保存设置（未保存则为默认值），保证首帧即有正确主题/动效。
    await settingsCubit.load();

    return AppDependencies(
      navigatorKey: navigatorKey,
      motionGovernor: governor,
      router: router,
      audio: audio,
      trainingRepo: trainingRepo,
      settingsRepo: settingsRepo,
      settingsCubit: settingsCubit,
    );
  }

  /// 替换页面登记表（feature 模块接入时使用），其余依赖原样保留。
  AppDependencies withPages(Map<String, AppPageBuilder> pages) =>
      AppDependencies(
        navigatorKey: navigatorKey,
        motionGovernor: motionGovernor,
        router: AppRouter(
          pages: router.pages.withPages(pages),
          motionLevelResolver: AppRouter.resolverFor(navigatorKey),
        ),
        audio: audio,
        trainingRepo: trainingRepo,
        settingsRepo: settingsRepo,
        settingsCubit: settingsCubit,
      );

  /// 把进程级依赖注入组件树：三个仓储走 [RepositoryProvider]，设置 Cubit 走
  /// [BlocProvider.value]（单例，生命周期与 App 等长，不随页面销毁）。
  ///
  /// 路由页（[AppPageBuilder]）内即可 `context.read<AudioService>()` /
  /// `context.read<TrainingRepository>()` / `context.read<SettingsRepository>()` /
  /// `context.read<SettingsCubit>()`，生产环境不再抛 `ProviderNotFoundException`。
  Widget providers({required Widget child}) => MultiRepositoryProvider(
        providers: <RepositoryProvider<dynamic>>[
          RepositoryProvider<AudioService>.value(value: audio),
          RepositoryProvider<TrainingRepository>.value(value: trainingRepo),
          RepositoryProvider<SettingsRepository>.value(value: settingsRepo),
        ],
        child: BlocProvider<SettingsCubit>.value(
          value: settingsCubit,
          child: child,
        ),
      );

  /// 释放资源；顺序与创建顺序相反。
  Future<void> dispose() async {
    await settingsCubit.close();
    await audio.dispose();
    motionGovernor
      ..stop()
      ..dispose();
  }
}
