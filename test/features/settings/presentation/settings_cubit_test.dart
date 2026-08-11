import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/features/settings/presentation/settings_cubit.dart';
import 'package:interval_ear/features/settings/presentation/settings_state.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/repositories/settings_repository.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppSettings.defaults);
  });

  group('SettingsCubit', () {
    late MockSettingsRepository repo;
    late SettingsCubit cubit;

    setUp(() {
      repo = MockSettingsRepository();
      cubit = SettingsCubit(repository: repo);
    });

    tearDown(() => cubit.close());

    test('initial state is SettingsInitial and current falls back to defaults',
        () {
      expect(cubit.state, isA<SettingsInitial>());
      expect(cubit.current, AppSettings.defaults);
    });

    test('load emits SettingsLoaded with the saved settings', () async {
      when(() => repo.load()).thenAnswer((_) async => AppSettings.defaults);
      await cubit.load();
      expect(cubit.state, isA<SettingsLoaded>());
      final SettingsLoaded loaded = cubit.state as SettingsLoaded;
      expect(loaded.settings, AppSettings.defaults);
      expect(cubit.current, AppSettings.defaults);
      verify(() => repo.load()).called(1);
    });

    test('update emits new state immediately and persists', () async {
      when(() => repo.load()).thenAnswer((_) async => AppSettings.defaults);
      when(() => repo.save(any())).thenAnswer((_) async {});
      await cubit.load();

      final AppSettings next =
          AppSettings.defaults.copyWith(themeMode: ThemePreference.dark);
      await cubit.update(next);

      expect(cubit.state, isA<SettingsLoaded>());
      expect(cubit.current.themeMode, ThemePreference.dark);
      verify(() => repo.save(next)).called(1);
    });

    test('update survives a failing save without throwing', () async {
      when(() => repo.load()).thenAnswer((_) async => AppSettings.defaults);
      when(() => repo.save(any()))
          .thenThrow(const FormatException('disk full'));
      await cubit.load();

      final AppSettings next =
          AppSettings.defaults.copyWith(motionPreference: MotionPreference.off);
      await cubit.update(next);

      expect(cubit.current.motionPreference, MotionPreference.off);
    });

    test('load 和 update 都会立即应用设置副作用', () async {
      final applied = <AppSettings>[];
      final callbackCubit = SettingsCubit(
        repository: repo,
        onApplied: applied.add,
      );
      when(() => repo.load()).thenAnswer((_) async => AppSettings.defaults);
      when(() => repo.save(any())).thenAnswer((_) async {});

      await callbackCubit.load();
      final next = AppSettings.defaults.copyWith(volume: 0.25);
      await callbackCubit.update(next);

      expect(applied, <AppSettings>[AppSettings.defaults, next]);
      await callbackCubit.close();
    });
  });
}
