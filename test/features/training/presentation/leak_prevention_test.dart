// 防泄露（P0 最高优先级，必须全部通过）：D1 答案区 m2/M7 一致、D2 可视化只来自
// EnvelopeSampler、D3 A/B 对比单缓冲单次播放。
//
// 全部使用 FakeAudioService + 虚拟时钟，不碰真实音频后端（架构 §7 共享知识）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:interval_ear/app/theme/app_theme.dart';
import 'package:interval_ear/core/audio/audio_playback_event.dart';
import 'package:interval_ear/core/audio/audio_sequence.dart';
import 'package:interval_ear/core/audio/audio_service.dart';
import 'package:interval_ear/core/audio/sfx_catalog.dart';
import 'package:interval_ear/core/audio/fake_audio_service.dart';
import 'package:interval_ear/core/audio/synth/envelope.dart';
import 'package:interval_ear/core/motion/motion_governor.dart';
import 'package:interval_ear/core/motion/motion_level.dart';
import 'package:interval_ear/core/motion/motion_scope.dart';
import 'package:interval_ear/features/training/domain/models/enums.dart';
import 'package:interval_ear/features/training/domain/models/interval_catalog.dart';
import 'package:interval_ear/features/training/domain/models/interval_id.dart';
import 'package:interval_ear/features/training/domain/models/interval_question.dart';
import 'package:interval_ear/features/training/domain/models/app_settings.dart';
import 'package:interval_ear/features/training/domain/models/training_attempt.dart';
import 'package:interval_ear/features/training/presentation/widgets/visualizer/breath_halo_painter.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_state.dart';
import 'package:interval_ear/features/training/presentation/cubit/training_view_model.dart';
import 'package:interval_ear/features/training/presentation/feedback/ab_compare_button.dart';
import 'package:interval_ear/features/training/presentation/feedback/feedback_controller.dart';
import 'package:interval_ear/features/training/presentation/widgets/answer_grid.dart';
import 'package:interval_ear/features/training/presentation/widgets/visualizer/playback_visualizer.dart';

/// 包裹待测组件，提供已挂载全部 ThemeExtension 的主题（与现有 widget 测试一致）。
///
/// [boxSize] 控制挂载容器尺寸：默认 360×240 适配大多数组件；答案网格需要更大空间
/// 以避免按钮因 `childAspectRatio` 被压缩到 `minTouchTarget` 以下而触发 RenderFlex
/// 溢出（溢出会被测试框架判为失败，与目标断言无关）。
Widget _bootstrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  MotionLevel? level,
  Size boxSize = const Size(360, 240),
}) {
  final ThemeData theme =
      brightness == Brightness.dark ? AppTheme.dark : AppTheme.light;
  final scaffold = Scaffold(
    body: Center(
      child: SizedBox(width: boxSize.width, height: boxSize.height, child: child),
    ),
  );
  if (level == null) {
    return MaterialApp(theme: theme, home: scaffold);
  }
  return MaterialApp(
    theme: theme,
    home: MotionScope(
      data: MotionScopeData(
        level: level,
        stage: MotionDegradeStage.none,
        userPreference: MotionPreference.system,
        systemReduceMotion: false,
      ),
      child: scaffold,
    ),
  );
}

/// 待测音频序列（root=60, target=64，与泄漏无关，仅驱动事件）。
AudioSequenceSpec _spec({Timbre timbre = Timbre.keyboard}) => AudioSequenceSpec(
      rootMidiNote: 60,
      targetMidiNote: 64,
      direction: PlaybackDirection.ascending,
      timbre: timbre,
    );

/// 计数型音频服务：委托 FakeAudioService，并统计 playComparison 调用次数（D3）。
class _CountingAudioService implements AudioService {
  _CountingAudioService() : fake = FakeAudioService()..initialize();
  final FakeAudioService fake;
  int playComparisonCalls = 0;

  @override
  Future<int> playComparison(List<AudioSequenceSpec> specs, Duration gapBetween) {
    playComparisonCalls++;
    return fake.playComparison(specs, gapBetween);
  }

  @override
  Future<void> initialize() => fake.initialize();
  @override
  bool get isAvailable => fake.isAvailable;
  @override
  bool get isPlaying => fake.isPlaying;
  @override
  int get currentPlaybackId => fake.currentPlaybackId;
  @override
  Stream<AudioPlaybackEvent> get events => fake.events;
  @override
  Future<int> playSequence(AudioSequenceSpec spec) => fake.playSequence(spec);
  @override
  Future<void> playSfx(SfxId id) => fake.playSfx(id);
  @override
  Future<void> stop() => fake.stop();
  @override
  Future<void> preload(Iterable<AudioSequenceSpec> specs) =>
      fake.preload(specs);
  @override
  void setMasterVolume(double volume) => fake.setMasterVolume(volume);
  @override
  Future<void> dispose() => fake.dispose();
}

/// 记录型音频服务：记录被访问的成员，用于断言可视化绝不读取 PCM/FFT/采样（D2）。
class _RecordingAudioService implements AudioService {
  _RecordingAudioService() : fake = FakeAudioService()..initialize();
  final FakeAudioService fake;
  final Set<Symbol> accessed = <Symbol>{};

  @override
  Future<int> playComparison(List<AudioSequenceSpec> specs, Duration gapBetween) {
    accessed.add(#playComparison);
    return fake.playComparison(specs, gapBetween);
  }

  @override
  Future<void> initialize() {
    accessed.add(#initialize);
    return fake.initialize();
  }

  @override
  bool get isAvailable {
    accessed.add(#isAvailable);
    return fake.isAvailable;
  }

  @override
  bool get isPlaying {
    accessed.add(#isPlaying);
    return fake.isPlaying;
  }

  @override
  int get currentPlaybackId {
    accessed.add(#currentPlaybackId);
    return fake.currentPlaybackId;
  }

  @override
  Stream<AudioPlaybackEvent> get events {
    accessed.add(#events);
    return fake.events;
  }

  @override
  Future<int> playSequence(AudioSequenceSpec spec) {
    accessed.add(#playSequence);
    return fake.playSequence(spec);
  }

  @override
  Future<void> playSfx(SfxId id) {
    accessed.add(#playSfx);
    return fake.playSfx(id);
  }

  @override
  Future<void> stop() {
    accessed.add(#stop);
    return fake.stop();
  }

  @override
  Future<void> preload(Iterable<AudioSequenceSpec> specs) {
    accessed.add(#preload);
    return fake.preload(specs);
  }

  @override
  void setMasterVolume(double volume) {
    accessed.add(#setMasterVolume);
    fake.setMasterVolume(volume);
  }

  @override
  Future<void> dispose() => fake.dispose();
}

IntervalQuestion _question(IntervalId correct) => IntervalQuestion(
      questionId: 'q_$correct',
      correctInterval: correct,
      rootMidiNote: 60,
      targetMidiNote: 60 + correct.semitones,
      direction: PlaybackDirection.ascending,
      timbre: Timbre.keyboard,
      rootMode: RootMode.limitedRandom,
      answerOptions: IntervalCatalog.sorted(IntervalCatalog.trainableIds),
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

TrainingAwaitingAnswer _awaiting(IntervalId correct) => TrainingAwaitingAnswer(
      question: _question(correct),
      answerOptions: IntervalCatalog.sorted(IntervalCatalog.trainableIds),
      index: 0,
      total: 5,
      combo: 0,
      canReplay: true,
      replayCount: 0,
    );

/// 把答案选项视图投影为「逐字段指纹」，用于比较两个题目的视图数据是否完全一致。
///
/// `AnswerOptionView` 是 lib 层的纯展示数据类，未覆写 `==`/`hashCode`（按领域设计
/// 不应被当值对象比较），因此不能用 `expect(listA, listB)` 这类依赖实例 identity 的
/// 断言。这里只抽取与「防音高泄露」相关的展示字段，确保 m2 与 M7 的答案区逐字段相同。
List<List<Object?>> _optionFingerprints(List<AnswerOptionView> options) =>
    options
        .map((o) => <Object?>[
              o.id,
              o.name,
              o.shorthand,
              o.semitones,
              o.isCorrect,
              o.isSelected,
            ])
        .toList();

void main() {
  group('D1 防泄露：awaiting 状态 m2 与 M7 答案区逐像素一致（T11 验收 A2）', () {
    test('两个题目的答案选项视图完全相同（无音高泄露）', () {
      final sM2 = _awaiting(IntervalId.minorSecond);
      final sM7 = _awaiting(IntervalId.majorSeventh);

      // awaiting 状态不暴露 correctInterval，答案选项只由半音数升序决定。
      expect(sM2.answerOptions, sM7.answerOptions);

      final optsM2 = TrainingViewModel.from(sM2).options;
      final optsM7 = TrainingViewModel.from(sM7).options;
      // AnswerOptionView 未覆写 ==（lib 层），逐字段指纹比对以验证「视图数据完全一致」，
      // 避免依赖实例 identity（那会让两个字段完全相同的对象被判不等，造成假阴性）。
      expect(_optionFingerprints(optsM2), _optionFingerprints(optsM7));

      // 作答前没有任何选项携带正确答案 / 所选标记。
      for (final o in optsM2) {
        expect(o.isCorrect, isFalse);
        expect(o.isSelected, isFalse);
      }
    });

    testWidgets('渲染出的答案网格文本完全相同（m2 vs M7 无差异）', (tester) async {
      final optsM2 = TrainingViewModel.from(_awaiting(IntervalId.minorSecond)).options;
      final optsM7 = TrainingViewModel.from(_awaiting(IntervalId.majorSeventh)).options;

      // 默认测试视口带 devicePixelRatio，逻辑宽高被压窄，会把挂载盒连同 3 列答案网格
      // 压到按钮 minTouchTarget 以下，触发 RenderFlex 溢出——这与「防泄露」目标断言无关，
      // 只会误判测试失败。这里显式放大逻辑视口并还原，仅改变布局容器尺寸，不影响答案
      // 选项内容，从而公平比较 m2 与 M7 的渲染文本。
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(2000, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.physicalSize = originalSize;
        tester.view.devicePixelRatio = originalDpr;
      });

      await tester.pumpWidget(_bootstrap(
        AnswerGrid(
          options: optsM2,
          enabled: true,
          onSelect: (_) {},
        ),
        boxSize: const Size(600, 1000),
      ));
      final textsM2 = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();

      await tester.pumpWidget(_bootstrap(
        AnswerGrid(
          options: optsM7,
          enabled: true,
          onSelect: (_) {},
        ),
        boxSize: const Size(600, 1000),
      ));
      final textsM7 = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();

      expect(textsM2, textsM7);
    });
  });

  group('D2 防泄露：可视化幅度只来自 EnvelopeSampler，不读 PCM/FFT（T12）', () {
    test('EnvelopeSampler.amplitudeAt 是时间纯函数：常量 600/350、边界正确', () {
      expect(EnvelopeSampler.kAttackMs, 600);
      expect(EnvelopeSampler.kReleaseMs, 350);
      // 边界：起音 0、收尾 0、峰值在 attackFrac。
      expect(EnvelopeSampler.amplitudeAt(Timbre.keyboard, 0), 0);
      expect(
          EnvelopeSampler.amplitudeAt(Timbre.keyboard, EnvelopeSampler.windowMs), 0);
      expect(
        EnvelopeSampler.amplitudeAt(Timbre.keyboard, EnvelopeSampler.kAttackMs),
        closeTo(1.0, 1e-9),
      );
      // 与音色无关（pitch 根本不是入参）。
      expect(
        EnvelopeSampler.amplitudeAt(Timbre.keyboard, 300),
        EnvelopeSampler.amplitudeAt(Timbre.plucked, 300),
      );
    });

    testWidgets('PlaybackVisualizer 仅订阅 audio.events，绝不读取 PCM/FFT/采样',
        (tester) async {
      final recording = _RecordingAudioService();
      await tester.pumpWidget(_bootstrap(PlaybackVisualizer(
        audio: recording,
        playbackId: 1,
        timbre: Timbre.keyboard,
        style: VisualizerStyle.halo,
      )));
      // 驱动一次播放事件流，模拟真实播放。
      recording.fake.playSequence(_spec());
      recording.fake.advance(const Duration(seconds: 2));
      // 可视化有常驻 Ticker（ambient 动画），pumpAndSettle 永不收敛；用有限帧即可。
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 32));

      // 只应访问 events 订阅；任何播放/对比/音效/采样读取都视为泄露。
      expect(recording.accessed.contains(#events), isTrue);
      expect(
        recording.accessed.intersection(<Symbol>{
          #playSequence,
          #playComparison,
          #playSfx,
          #stop,
          #preload,
          #setMasterVolume,
        }),
        isEmpty,
      );
      await recording.dispose();
    });

    testWidgets('PlaybackVisualizer 振幅与音色无关（pitch/frequency 不泄露）',
        (tester) async {
      final audio = FakeAudioService()..initialize();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 100,
                height: 100,
                child: PlaybackVisualizer(
                  audio: audio,
                  playbackId: 1,
                  timbre: Timbre.keyboard,
                  style: VisualizerStyle.halo,
                ),
              ),
              SizedBox(
                width: 100,
                height: 100,
                child: PlaybackVisualizer(
                  audio: audio,
                  playbackId: 1,
                  timbre: Timbre.plucked,
                  style: VisualizerStyle.halo,
                ),
              ),
            ],
          ),
        ),
      ));

      audio.playSequence(_spec());
      audio.advance(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 120));

      // BreathHaloPainter 是 CustomPainter（非 Widget），通过 CustomPaint 取出。
      final paints =
          tester.widgetList<CustomPaint>(find.byType(CustomPaint)).toList();
      final painters = paints
          .map((p) => p.painter)
          .whereType<BreathHaloPainter>()
          .toList();
      expect(painters.length, 2);
      final amp1 = painters[0].amplitude;
      final amp2 = painters[1].amplitude;
      // 不同音色下振幅完全一致：可视化与音高/音色无关。
      expect(amp1, greaterThan(0.0));
      expect((amp1 - amp2).abs(), lessThan(0.02));
      await audio.dispose();
    });
  });

  group('D3 防泄露：A/B 对比单缓冲，playComparison 恰好一次（T13 验收 1）', () {
    testWidgets('点击对比：playComparison 仅调用一次；对比中再次点击被忽略',
        (tester) async {
      final audio = _CountingAudioService();
      final question = _question(IntervalId.minorThird);
      final attempt = TrainingAttempt(
        attemptId: 'a1',
        sessionId: 's1',
        questionId: 'q',
        correctInterval: IntervalId.minorThird,
        selectedInterval: IntervalId.majorThird,
        isUncertain: false,
        replayCount: 0,
        responseDuration: Duration.zero,
        direction: PlaybackDirection.ascending,
        timbre: Timbre.keyboard,
        rootMode: RootMode.limitedRandom,
        rootMidiNote: 60,
        answerMode: AnswerMode.enabledOnly,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

      await tester.pumpWidget(_bootstrap(FeedbackController(
        audio: audio,
        question: question,
        attempt: attempt,
        builder: (ctx, handle) => ABCompareButton(handle: handle),
      )));

      // 第一次点击：触发一次对比播放。
      await tester.tap(find.byType(ABCompareButton));
      await tester.pump();
      expect(audio.playComparisonCalls, 1);

      // 对比进行中（未收到 sequenceEnd）再次点击：被单缓冲忽略。
      await tester.tap(find.byType(ABCompareButton));
      await tester.pump();
      expect(audio.playComparisonCalls, 1);

      // 推进到 sequenceEnd，_comparing 复位；再次点击 → 第二次调用。
      // 对比序列为 4 段旋律（每段 ~2.4s）+ 段间间隔，单次大跨度推进确保整段播完。
      audio.fake.advance(const Duration(seconds: 60));
      await tester.pump();
      await tester.tap(find.byType(ABCompareButton));
      await tester.pump();
      expect(audio.playComparisonCalls, 2);

      await audio.dispose();
    });
  });
}
