import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/core/constants/app_strings.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/session_summary/presentation/widgets/mistake_list.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';

import '../../test_support.dart';

void main() {
  testWidgets('错题清单逐条复用对比播放，点击触发 playComparison', (tester) async {
    final mistakes = <TrainingAttempt>[
      makeAttempt(
        correct: IntervalId.perfectFifth,
        selected: IntervalId.perfectFourth,
      ),
    ];
    final FakeAudioService audio = FakeAudioService();
    // Fake 需在 initialize 后 isAvailable 才为真，否则 playComparison 直接报错、不发声。
    await audio.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MotionScope(
          data: const MotionScopeData(
            level: MotionLevel.reduced,
            stage: MotionDegradeStage.none,
            userPreference: MotionPreference.system,
            systemReduceMotion: false,
          ),
          child: RepositoryProvider<AudioService>.value(
            value: audio,
            child: Scaffold(body: MistakeList(mistakes: mistakes)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 错题标题与复用 T13 的 A/B 对比按钮。
    expect(find.textContaining('错题 1'), findsOneWidget);
    final Finder ab = find.byIcon(Icons.compare_arrows_rounded);
    expect(ab, findsOneWidget);

    await tester.tap(ab);
    // playComparison 同步启动（_beginRender 在首个 await 之前执行）。
    expect(audio.isPlaying, isTrue);

    // 对比序列为 4 段（每段两音 × 1100ms + 120ms 间隔）+ 3 段间 320ms 静音，
    // 总时长约 10.3s，需推进足够时长才能完成。
    audio.advance(const Duration(seconds: 30));
    await tester.pump();
    expect(audio.isPlaying, isFalse);
  });

  testWidgets('无错题时展示空态且不渲染对比按钮', (tester) async {
    final FakeAudioService audio = FakeAudioService();
    await audio.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MotionScope(
          data: const MotionScopeData(
            level: MotionLevel.reduced,
            stage: MotionDegradeStage.none,
            userPreference: MotionPreference.system,
            systemReduceMotion: false,
          ),
          child: RepositoryProvider<AudioService>.value(
            value: audio,
            child: Scaffold(body: MistakeList(mistakes: const <TrainingAttempt>[])),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.common.empty), findsWidgets);
    expect(find.byIcon(Icons.compare_arrows_rounded), findsNothing);
  });
}
