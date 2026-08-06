import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/settings/presentation/settings_cubit.dart';
import 'package:interval_ear/features/settings/presentation/settings_page.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';
import 'package:interval_ear/features/training/domain/repositories/training_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockTrainingRepository extends Mock implements TrainingRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppSettings.defaults);
  });

  late MockSettingsRepository settingsRepo;
  late MockTrainingRepository trainingRepo;
  late SettingsCubit cubit;

  setUp(() {
    settingsRepo = MockSettingsRepository();
    trainingRepo = MockTrainingRepository();
    cubit = SettingsCubit(repository: settingsRepo);
  });

  tearDown(() => cubit.close());

  Future<void> pump(WidgetTester tester) async {
    when(() => settingsRepo.load()).thenAnswer((_) async => AppSettings.defaults);
    when(() => settingsRepo.save(any())).thenAnswer((_) async {});
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MotionScope(
          data: const MotionScopeData(
            level: MotionLevel.full,
            stage: MotionDegradeStage.none,
            userPreference: MotionPreference.system,
            systemReduceMotion: false,
          ),
          child: MultiRepositoryProvider(
            providers: <RepositoryProvider<dynamic>>[
              RepositoryProvider<AudioService>.value(value: FakeAudioService()),
              RepositoryProvider<TrainingRepository>.value(
                value: trainingRepo,
              ),
            ],
            child: BlocProvider<SettingsCubit>.value(
              value: cubit,
              child: const SettingsPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders title and core sections', (tester) async {
    await pump(tester);
    expect(find.text(AppStrings.settings.title), findsOneWidget);
    expect(find.text(AppStrings.settings.themeMode), findsOneWidget);
    expect(
      find.text(AppStrings.settings.showIntervalShorthand),
      findsOneWidget,
    );
    // 数据/关于分区位于可滚动 ListView 的屏外，未进入视口时不会被实例化，
    // 需先向下滚动让这两个分区被构建后再断言。
    await tester.scrollUntilVisible(
      find.text(AppStrings.settings.aboutSection),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.settings.dataSection), findsOneWidget);
    expect(find.text(AppStrings.settings.aboutSection), findsOneWidget);
  });

  testWidgets('tapping a switch tile toggles the setting via cubit',
      (tester) async {
    await pump(tester);
    expect(cubit.current.showIntervalShorthand, isFalse);
    await tester.tap(
      find.widgetWithText(ListTile, AppStrings.settings.showIntervalShorthand),
    );
    await tester.pumpAndSettle();
    expect(cubit.current.showIntervalShorthand, isTrue);
    verify(() => settingsRepo.save(any())).called(1);
  });

  testWidgets('segmented theme control updates the setting', (tester) async {
    await pump(tester);
    expect(cubit.current.themeMode, ThemePreference.system);
    await tester.tap(find.text(AppStrings.settings.themeDark));
    await tester.pumpAndSettle();
    expect(cubit.current.themeMode, ThemePreference.dark);
  });

  testWidgets('does not crash when rendered', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
  });
}
